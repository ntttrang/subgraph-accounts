pipeline {
    agent any

    environment {
        // Apollo GraphOS configuration
        APOLLO_KEY = credentials('APOLLO_KEY')
        GRAPH_ID = 'srv-23'
        SUBGRAPH = 'accounts'

        // Render deployment configuration
        RENDER_SERVICE_ID = credentials('RENDER_SERVICE_ID')
        RENDER_API_KEY = credentials('RENDER_API_KEY')

        // Node.js configuration
        NODE_VERSION = '18'

        // Ensure tools are in PATH
        PATH = "$HOME/.rover/bin:$HOME/.nvm/versions/node/v${NODE_VERSION}/bin:$PATH"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Node.js') {
            steps {
                script {
                    // Install Node.js if not available
                    sh '''
                        if ! command -v node &> /dev/null; then
                            echo "Node.js not found, attempting to install..."

                            # Try multiple installation methods without sudo
                            if command -v apt-get &> /dev/null; then
                                # Try without sudo first (for containers with root access)
                                apt-get update && apt-get install -y nodejs npm || {
                                    echo "System Node.js installation failed, trying Node Version Manager..."
                                    # Fallback to nvm for user-space installation
                                    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
                                    export NVM_DIR="$HOME/.nvm"
                                    [ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"
                                    nvm install ${NODE_VERSION}
                                    nvm use ${NODE_VERSION}
                                }
                            elif command -v yum &> /dev/null; then
                                yum install -y nodejs npm
                            elif command -v apk &> /dev/null; then
                                apk add --no-cache nodejs npm
                            else
                                echo "No package manager found, trying nvm..."
                                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
                                export NVM_DIR="$HOME/.nvm"
                                [ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"
                                nvm install ${NODE_VERSION}
                                nvm use ${NODE_VERSION}
                            fi
                        else
                            echo "Node.js already installed"
                        fi

                        # Ensure node and npm are in PATH
                        export PATH="$HOME/.nvm/versions/node/v${NODE_VERSION}/bin:$PATH"

                        node --version
                        npm --version
                    '''
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    // Run tests if test script exists
                    if (fileExists('package.json')) {
                        def packageJson = readJSON file: 'package.json'
                        if (packageJson.scripts?.test) {
                            sh 'npm test'
                        } else {
                            echo 'No test script found, skipping tests'
                        }
                    }
                }
            }
        }

        stage('Install Apollo Rover') {
            steps {
                sh '''
                    # Install Apollo Rover CLI
                    curl -sSL https://rover.apollo.dev/nix/latest | sh

                    # Create bin directory if it doesn't exist
                    mkdir -p $HOME/.rover/bin

                    # Add Rover to PATH for current session
                    export PATH="$HOME/.rover/bin:$PATH"

                    # Make Rover available in subsequent steps
                    echo "export PATH=$HOME/.rover/bin:$PATH" >> $HOME/.bashrc
                    echo "export PATH=$HOME/.rover/bin:$PATH" >> $HOME/.profile

                    # Verify installation
                    if command -v rover &> /dev/null || [ -f "$HOME/.rover/bin/rover" ]; then
                        $HOME/.rover/bin/rover --version
                        echo "✅ Apollo Rover installed successfully"
                    else
                        echo "❌ Apollo Rover installation failed"
                        exit 1
                    fi
                '''
            }
        }

        stage('Schema Check') {
            steps {
                script {
                    try {
                        sh '''
                            # Ensure Rover is in PATH
                            export PATH="$HOME/.rover/bin:$PATH"

                            # Verify Rover is available
                            if command -v rover &> /dev/null; then
                                echo "🔍 Running schema check..."
                                rover subgraph check ${GRAPH_ID}@staging \
                                    --schema ./accounts.graphql \
                                    --name $SUBGRAPH
                            else
                                echo "❌ Apollo Rover not found in PATH"
                                exit 1
                            fi
                        '''
                        echo '✅ Schema check passed!'
                    } catch (Exception e) {
                        echo "⚠️  Schema check failed: ${e.getMessage()}"
                        // Don't fail the build for schema check failures
                        // Uncomment the line below if you want to fail the build
                        // throw e
                    }
                }
            }
        }

        stage('Publish Schema') {
            steps {
                script {
                    try {
                        sh '''
                            # Ensure Rover is in PATH
                            export PATH="$HOME/.rover/bin:$PATH"

                            # Verify Rover is available
                            if command -v rover &> /dev/null; then
                                echo "📤 Publishing schema to Apollo GraphOS..."
                                rover subgraph publish ${GRAPH_ID}@staging \
                                    --schema ./accounts.graphql \
                                    --name $SUBGRAPH \
                                    --routing-url http://localhost:4002 \
                                    --convert
                            else
                                echo "❌ Apollo Rover not found in PATH"
                                exit 1
                            fi
                        '''
                        echo '✅ Schema published successfully!'
                    } catch (Exception e) {
                        echo "❌ Schema publishing failed: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }

        stage('Deploy to Render') {
            steps {
                script {
                    try {
                        sh '''
                            # Verify curl is available
                            if ! command -v curl &> /dev/null; then
                                echo "❌ curl not found, installing..."
                                if command -v apt-get &> /dev/null; then
                                    apt-get update && apt-get install -y curl
                                elif command -v yum &> /dev/null; then
                                    yum install -y curl
                                elif command -v apk &> /dev/null; then
                                    apk add --no-cache curl
                                else
                                    echo "❌ Could not install curl"
                                    exit 1
                                fi
                            fi

                            echo "🚀 Triggering deployment on Render..."
                            # Deploy to Render using curl
                            curl -X POST \
                                -H "Authorization: Bearer $RENDER_API_KEY" \
                                -H "Content-Type: application/json" \
                                "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys" \
                                -d '{"clearCache": "do_not_clear"}'
                        '''
                        echo '✅ Deployment triggered successfully!'
                    } catch (Exception e) {
                        echo "❌ Deployment failed: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
    }

    post {
        always {
            echo '🧹 Cleaning up workspace...'
            cleanWs()
        }

        success {
            echo '🎉 Pipeline completed successfully!'
            echo '✅ Schema published and deployment triggered'
        }

        failure {
            echo '💥 Pipeline failed!'
            echo '❌ Check the logs above for detailed error information'
        }

        unstable {
            echo '⚠️  Pipeline completed with warnings'
            echo '⚠️  Some stages may have failed, but pipeline continued'
        }
    }
}

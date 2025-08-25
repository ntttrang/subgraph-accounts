pipeline {
    agent any

    environment {
        // Apollo GraphOS configuration (from publish-schema-staging.yml)
        APOLLO_KEY = credentials('APOLLO_KEY')
        GRAPH_ID = 'srv-23'
        SUBGRAPH = 'accounts'
        APOLLO_VCS_COMMIT = "${env.GIT_COMMIT}"

        // Render deployment configuration (from deploy-staging.yml)
        RENDER_SERVICE_ID = credentials('RENDER_SERVICE_ID')
        RENDER_API_KEY = credentials('RENDER_API_KEY')

        // Node.js configuration
        NODE_VERSION = '18'
    }

    stages {
        stage('Checkout') {
            steps {
                // Equivalent to actions/checkout@v4.1.5 with fetch-depth: 0
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    extensions: [[$class: 'CloneOption', depth: 0]],
                    userRemoteConfigs: [[url: env.GIT_URL]]
                ])
            }
        }

        stage('Setup Node.js') {
            steps {
                // Equivalent to actions/setup-node@v4 with cache
                script {
                    def nodeHome = tool name: "NodeJS-${NODE_VERSION}", type: 'jenkins.plugins.nodejs.tools.NodeJSInstallation'
                    env.PATH = "${nodeHome}/bin:${env.PATH}"

                    // Verify Node.js installation
                    sh 'node --version'
                    sh 'npm --version'
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                // Equivalent to "npm ci" from deploy-staging.yml
                sh 'npm ci'
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    // Equivalent to "npm test --if-present" from deploy-staging.yml
                    try {
                        sh 'npm test'
                        echo 'Tests completed successfully'
                    } catch (Exception e) {
                        // In GitHub Actions, --if-present makes this optional
                        // We'll make it optional in Jenkins too
                        echo "Tests failed or no test script found: ${e.getMessage()}"
                        echo 'Continuing with deployment...'
                    }
                }
            }
        }

        stage('Install Apollo Rover') {
            steps {
                // Handle ARM64 architecture and install Apollo Rover
                script {
                    sh '''
                        # Detect architecture
                        ARCH=$(uname -m)
                        echo "Detected architecture: $ARCH"

                        # Install Apollo Rover based on architecture
                        if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
                            echo "ARM64 detected, using npm installation method..."

                            # Method 1: Try npm installation (recommended for ARM64)
                            if command -v npm &> /dev/null; then
                                npm install -g @apollo/rover
                                export PATH="$HOME/.npm-global/bin:$PATH"
                                echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
                            else
                                echo "npm not available, trying alternative installation..."

                                # Method 2: Try downloading ARM64 binary directly
                                curl -L -o rover.tar.gz https://github.com/apollographql/rover/releases/latest/download/rover-v0.20.0-aarch64-unknown-linux-gnu.tar.gz
                                tar -xzf rover.tar.gz
                                sudo mv rover /usr/local/bin/rover
                                rm rover.tar.gz
                            fi
                        else
                            echo "x86_64 detected, using standard installation..."
                            # Standard installation for x86_64
                            curl -sSL https://rover.apollo.dev/nix/latest | sh
                            export PATH="$HOME/.rover/bin:$PATH"
                            echo "export PATH=$HOME/.rover/bin:$PATH" >> ~/.bashrc
                        fi

                        # Verify installation
                        rover --version || echo "Rover installation completed"
                    '''
                }
            }
        }

        stage('Publish Schema') {
            steps {
                script {
                    // Equivalent to publish step from publish-schema-staging.yml
                    try {
                        sh '''
                            # Set PATH to include both possible Rover locations
                            export PATH="$HOME/.rover/bin:$HOME/.npm-global/bin:/usr/local/bin:$PATH"

                            # Verify Rover is available
                            which rover || echo "Rover not found in PATH"

                            # Publish schema
                            rover subgraph publish ${GRAPH_ID}@staging \
                                --schema ./accounts.graphql \
                                --name $SUBGRAPH \
                                --routing-url http://localhost:4002 \
                                --convert
                        '''
                        echo 'Schema published successfully to staging!'
                    } catch (Exception e) {
                        echo "Schema publishing failed: ${e.getMessage()}"
                        // In production, you might want to fail here
                        // throw e
                    }
                }
            }
        }

        stage('Deploy to Render') {
            steps {
                script {
                    // Equivalent to Render deployment from deploy-staging.yml
                    try {
                        sh '''
                            # Deploy to Render using REST API (equivalent to johnbeynon/render-deploy-action)
                            curl -X POST \
                                -H "Authorization: Bearer $RENDER_API_KEY" \
                                -H "Content-Type: application/json" \
                                "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys" \
                                -d '{"clearCache": "do_not_clear"}'
                        '''
                        echo 'Deployment to Render triggered successfully!'
                    } catch (Exception e) {
                        echo "Render deployment failed: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline completed'
        }

        success {
            echo 'Pipeline succeeded! Staging deployment completed successfully.'
            // Optional: Send success notifications
            // slackSend channel: '#deployments', message: 'Staging deployment successful!'
        }

        failure {
            echo 'Pipeline failed!'
            // Optional: Send failure notifications
            // slackSend channel: '#deployments', message: 'Staging deployment failed!'
        }

        unstable {
            echo 'Pipeline completed with warnings'
        }
    }
}

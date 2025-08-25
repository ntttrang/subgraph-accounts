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
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
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

                    # Add Rover to PATH
                    export PATH="$HOME/.rover/bin:$PATH"
                    echo "export PATH=$HOME/.rover/bin:$PATH" >> ~/.bashrc

                    # Verify installation
                    $HOME/.rover/bin/rover --version
                '''
            }
        }

        stage('Schema Check') {
            steps {
                script {
                    try {
                        sh '''
                            export PATH="$HOME/.rover/bin:$PATH"
                            rover subgraph check ${GRAPH_ID}@staging \
                                --schema ./accounts.graphql \
                                --name $SUBGRAPH
                        '''
                        echo 'Schema check passed!'
                    } catch (Exception e) {
                        echo "Schema check failed: ${e.getMessage()}"
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
                            export PATH="$HOME/.rover/bin:$PATH"
                            rover subgraph publish ${GRAPH_ID}@staging \
                                --schema ./accounts.graphql \
                                --name $SUBGRAPH \
                                --routing-url http://localhost:4002 \
                                --convert
                        '''
                        echo 'Schema published successfully!'
                    } catch (Exception e) {
                        echo "Schema publishing failed: ${e.getMessage()}"
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
                            # Deploy to Render using curl
                            curl -X POST \
                                -H "Authorization: Bearer $RENDER_API_KEY" \
                                -H "Content-Type: application/json" \
                                "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys" \
                                -d '{"clearCache": "do_not_clear"}'
                        '''
                        echo 'Deployment triggered successfully!'
                    } catch (Exception e) {
                        echo "Deployment failed: ${e.getMessage()}"
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
            echo 'Pipeline succeeded!'
            // Send success notifications here
        }

        failure {
            echo 'Pipeline failed!'
            // Send failure notifications here
        }

        unstable {
            echo 'Pipeline unstable'
        }
    }
}

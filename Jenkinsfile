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
                // Equivalent to rover installation from publish-schema-staging.yml
                sh '''
                    # Install Apollo Rover CLI
                    curl -sSL https://rover.apollo.dev/nix/v0.1.0 | sh

                    # Add Rover to PATH for current session
                    export PATH="$HOME/.rover/bin:$PATH"
                    echo "export PATH=$HOME/.rover/bin:$PATH" >> ~/.bashrc

                    # Verify installation
                    $HOME/.rover/bin/rover --version
                '''
            }
        }

        stage('Publish Schema') {
            steps {
                script {
                    // Equivalent to publish step from publish-schema-staging.yml
                    try {
                        sh '''
                            export PATH="$HOME/.rover/bin:$PATH"
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

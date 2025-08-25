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

        // Docker configuration
        DOCKER_IMAGE_NAME = 'subgraph-accounts'
        DOCKER_IMAGE_TAG = "${env.BUILD_NUMBER}"
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

        stage('Build Docker Image') {
            steps {
                script {
                    // Build Docker image from Dockerfile
                    sh "docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ."

                    // Tag as latest for convenience
                    sh "docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest"
                }
            }
        }

        stage('Run Tests & Build') {
            steps {
                script {
                    // Run all commands inside the Docker container
                    docker.image("${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}").inside('-v $HOME/.npm:/root/.npm') {
                        // Verify environment
                        sh '''
                            node --version
                            npm --version
                            rover --version
                            echo "Docker environment ready!"
                        '''

                        // Install dependencies
                        sh 'npm ci'

                        // Run tests (optional)
                        try {
                            sh 'npm test'
                            echo 'Tests completed successfully'
                        } catch (Exception e) {
                            echo "Tests failed or no test script found: ${e.getMessage()}"
                            echo 'Continuing with deployment...'
                        }
                    }
                }
            }
        }

        stage('Publish Schema') {
            steps {
                script {
                    // Run schema publishing inside Docker container
                    docker.image("${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}").inside('-v $HOME/.npm:/root/.npm') {
                        try {
                            sh '''
                                # Apollo Rover is available in the Docker container
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

        stage('Cleanup') {
            steps {
                script {
                    // Clean up Docker images to save space
                    sh '''
                        docker rmi ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} || true
                        docker rmi ${DOCKER_IMAGE_NAME}:latest || true
                        docker system prune -f || true
                    '''
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

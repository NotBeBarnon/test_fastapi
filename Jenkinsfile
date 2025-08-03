pipeline {
    agent {
        docker {
            image 'python:3.11-slim'
            args '-v /var/run/docker.sock:/var/run/docker.sock --pull never'   // 本地有就不再pull
            // 或者 --pull missing
        }
    }
    triggers {
        GenericTrigger(
            genericVariables: [
                [key: 'CODING_REF', value: '$.ref'],
                [key: 'CODING_REPOSITORY', value: '$.repository.clone_url']
            ],
            token: 'fastapi-demo',  // 自定义，安全即可
            causeString: 'Triggered by CODING push',
            printContributedVariables: false,
            printPostContent: false
        )
    }

    environment {
        // 镜像名（不含 tag）
        IMAGE_NAME = 'frp.z33.fun:23827/test_fastapi-demo'
        REGISTRY   = 'http://frp.z33.fun:23827'

        // 凭据 ID（与 Jenkins 全局凭据保持一致）
        REGISTRY_CREDS = credentials('registry-auth')   // Username/Password
        SSH_CREDS      = 'prod-ssh'                     // SSH Username with private key
        DEPLOY_HOST    = 'frp.z33.fun'
        DEPLOY_PORT    = '23822'
        DEPLOY_USER    = 'bistu'
        APP_PORT       = '8099'
        DOCKER_PORT    = '8089'
    }

    stages {

        /* ---------- 1. 拉取源码 ---------- */
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        /* ---------- 2. 单元测试 ---------- */
        stage('Test') {
            steps {
                sh 'python3 -m pip install --upgrade pip'
                sh 'python3 -m pip install -r requirements.txt'
//                 sh 'pytest app/ -v'
            }
        }

        /* ---------- 3. 构建镜像 ---------- */
        stage('Build & Tag') {
            steps {
                script {
                    dockerImage = docker.build("${IMAGE_NAME}:${BUILD_NUMBER}")
                }
            }
        }

        /* ---------- 4. 推送镜像 ---------- */
        stage('Push') {
            steps {
                script {
                    docker.withRegistry("${REGISTRY}", 'registry-auth') {
                        dockerImage.push()
//                         dockerImage.push('latest')
                    }
                }
            }
        }

        /* ---------- 5. 部署到目标服务器 ---------- */
        stage('Deploy') {
            steps {
                sh 'apt-get update && apt-get install -y openssh-client'   // 先装 ssh
                sshagent(credentials: ["${SSH_CREDS}"]) {
                    sh """
                       ssh -o StrictHostKeyChecking=no \
                           -p ${DEPLOY_PORT} \
                           ${DEPLOY_USER}@${DEPLOY_HOST} << 'ENDSSH'
set -e
docker pull ${IMAGE_NAME}:${BUILD_NUMBER}
docker stop fastapi-demo || true
docker rm   fastapi-demo || true
docker run -d --name fastapi-demo \
           -p ${APP_PORT}:${DOCKER_PORT} \
           --restart unless-stopped \
           ${IMAGE_NAME}:${BUILD_NUMBER}
ENDSSH
                    """
                }
            }
        }
    }

    post {
        always  { echo 'Pipeline finished.' }
        failure { echo 'Build failed! Check logs.' }
    }
}

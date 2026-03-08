pipeline {
    agent any

    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        // 不要 skipDefaultCheckout，否则 workspace 里没代码
        // skipDefaultCheckout(true)
    }

    parameters {
        string(name: 'IMAGE_REPO', defaultValue: '', description: '镜像仓库地址（必填）')
        string(name: 'IMAGE_TAG', defaultValue: '', description: '镜像标签（空自动生成）')
        string(name: 'DOCKERFILE_PATH', defaultValue: 'Dockerfile', description: 'Dockerfile 路径')

        string(name: 'PLATFORM_CALLBACK_URL', defaultValue: '', description: '平台回调地址')
        string(name: 'PIPELINE_ID', defaultValue: '', description: '平台流水线ID')

        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: '跳过单元测试')
        string(name: 'GO_VERSION', defaultValue: '1.22', description: 'Dockerfile 构建参数中的 Go 版本')
    }

    environment {
        GOROOT         = "/usr/local/go"
        GOPATH         = "/var/lib/jenkins/go"
        GOMODCACHE     = "/var/lib/jenkins/go/pkg/mod"
        GOCACHE        = "/var/lib/jenkins/.cache/go-build"
        PATH           = "/usr/local/go/bin:${env.GOPATH}/bin:${env.PATH}"

        REGISTRY_CREDS = credentials('harbor-registry')
        HMAC_SECRET    = credentials('hmac-secret')
        GOPROXY        = 'https://goproxy.cn,direct'
        CGO_ENABLED    = '0'
        GOOS           = 'linux'
        GOARCH         = 'amd64'
    }

    stages {

        stage('Checkout Info') {
            steps {
                echo "=== 使用 Jenkins 已拉取代码（避免重复 checkout） ==="

                script {
                    if (!params.IMAGE_REPO?.trim()) {
                        error("IMAGE_REPO 不能为空")
                    }

                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.GIT_COMMIT_FULL  = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.GIT_COMMIT_MSG   = sh(script: 'git log -1 --pretty=%B | head -1', returnStdout: true).trim()

                    env.GIT_BRANCH_NAME = sh(
                        script: '''
                            branch=$(git symbolic-ref --short -q HEAD || true)
                            if [ -n "$branch" ]; then
                              echo "$branch"
                            elif [ -n "$GIT_BRANCH" ]; then
                              echo "$GIT_BRANCH"
                            else
                              echo "unknown"
                            fi
                        ''',
                        returnStdout: true
                    ).trim().replaceAll('^origin/', '').replaceAll('/', '-')

                    env.BUILD_TS = sh(script: 'date +%Y%m%d%H%M%S', returnStdout: true).trim()

                    env.FINAL_TAG = params.IMAGE_TAG?.trim()
                        ? params.IMAGE_TAG.trim()
                        : "${env.GIT_BRANCH_NAME}-${env.GIT_COMMIT_SHORT}-${env.BUILD_TS}"

                    env.FULL_IMAGE = "${params.IMAGE_REPO}:${env.FINAL_TAG}"

                    echo "Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Branch: ${env.GIT_BRANCH_NAME}"
                    echo "Image : ${env.FULL_IMAGE}"
                }
            }
            post {
                success { script { stageCallback('checkout', 'success') } }
                failure { script { stageCallback('checkout', 'failed') } }
            }
        }

        stage('Dependencies') {
            steps {
                echo "=== 下载依赖 ==="
                script {
                    if (!fileExists('go.mod')) {
                        echo "未检测到 go.mod，跳过依赖下载"
                        return
                    }

                    sh '''
                        set -e
                        go version
                        go env GOMODCACHE
                        go env GOCACHE
                        go mod download
                        go mod verify
                    '''
                }
            }
            post {
                success { script { stageCallback('dependencies', 'success') } }
                failure { script { stageCallback('dependencies', 'failed') } }
            }
        }

        stage('Compile Check') {
            steps {
                echo "=== 编译检查 / 预热缓存 ==="
                script {
                    if (!fileExists('go.mod')) {
                        echo "未检测到 go.mod，跳过编译检查"
                        return
                    }

                    sh '''
                        set -e
                        go test -run '^$' ./...
                    '''
                }
            }
            post {
                success { script { stageCallback('compile', 'success') } }
                failure { script { stageCallback('compile', 'failed') } }
            }
        }

        stage('Test') {
            when { expression { return !params.SKIP_TESTS } }
            steps {
                echo "=== 执行测试 ==="
                script {
                    if (!fileExists('go.mod')) {
                        echo "未检测到 go.mod，跳过测试"
                        return
                    }

                    def hasTests = sh(
                        script: "find . -name '*_test.go' | grep . >/dev/null 2>&1 && echo yes || echo no",
                        returnStdout: true
                    ).trim()

                    if (hasTests != 'yes') {
                        echo "未检测到任何 *_test.go，跳过真实测试"
                        return
                    }

                    sh '''
                        set -e
                        go test -v -coverprofile=coverage.out ./...
                        go tool cover -func=coverage.out | tail -1
                    '''
                }
            }
            post {
                success { script { stageCallback('test', 'success') } }
                failure { script { stageCallback('test', 'failed') } }
            }
        }

        stage('Lint') {
            when { expression { return !params.SKIP_TESTS } }
            steps {
                echo "=== 代码检查 ==="
                script {
                    def hasLint = sh(
                        script: "which golangci-lint >/dev/null 2>&1 && echo 'yes' || echo 'no'",
                        returnStdout: true
                    ).trim()

                    if (hasLint == 'yes') {
                        sh 'golangci-lint run --timeout=5m || true'
                    } else {
                        echo "未安装 golangci-lint，使用 go vet"
                        sh 'go vet ./...'
                    }
                }
            }
            post {
                success { script { stageCallback('lint', 'success') } }
                failure { script { stageCallback('lint', 'failed') } }
            }
        }

        stage('Build Image') {
            steps {
                echo "=== 构建镜像 ==="
                sh """
                    set -e
                    nerdctl build \
                        -t ${env.FULL_IMAGE} \
                        -f ${params.DOCKERFILE_PATH} \
                        --build-arg GO_VERSION=${params.GO_VERSION} \
                        --label git.commit=${env.GIT_COMMIT_FULL} \
                        --label git.branch=${env.GIT_BRANCH_NAME} \
                        --label build.number=${env.BUILD_NUMBER} \
                        --label build.timestamp=${env.BUILD_TS} \
                        .
                """
            }
            post {
                success { script { stageCallback('build', 'success') } }
                failure { script { stageCallback('build', 'failed') } }
            }
        }

        stage('Push Image') {
            steps {
                echo "=== 推送镜像 ==="
                script {
                    def registryHost = params.IMAGE_REPO.split('/')[0]

                    sh """
                        set -e
                        echo \${REGISTRY_CREDS_PSW} | nerdctl login -u \${REGISTRY_CREDS_USR} --password-stdin ${registryHost}
                        nerdctl push ${env.FULL_IMAGE}
                    """

                    env.IMAGE_DIGEST = sh(
                        script: """
                            nerdctl inspect ${env.FULL_IMAGE} \
                            --format '{{range .RepoDigests}}{{println .}}{{end}}' \
                            2>/dev/null | grep -oE 'sha256:[a-f0-9]+' | head -1 || echo ''
                        """,
                        returnStdout: true
                    ).trim()

                    env.IMAGE_WITH_DIGEST = env.IMAGE_DIGEST
                        ? "${params.IMAGE_REPO}@${env.IMAGE_DIGEST}"
                        : env.FULL_IMAGE

                    echo "Digest: ${env.IMAGE_DIGEST ?: '未获取到'}"
                    echo "Deploy Image: ${env.IMAGE_WITH_DIGEST}"
                }
            }
            post {
                success { script { stageCallback('push', 'success') } }
                failure { script { stageCallback('push', 'failed') } }
            }
        }
    }

    post {
        success { script { callbackPlatform('SUCCESS', 'Go 项目构建成功') } }
        failure { script { callbackPlatform('FAILURE', 'Go 项目构建失败') } }
        aborted { script { callbackPlatform('ABORTED', '构建中止') } }
        always {
            sh "nerdctl rmi ${env.FULL_IMAGE} || true"
            cleanWs()
        }
    }
}

// ==================== 阶段级回调（实时更新UI） ====================
def stageCallback(String stageType, String status) {
    if (!params.PLATFORM_CALLBACK_URL?.trim()) {
        return
    }

    try {
        def payload = [
            job_name     : env.JOB_NAME,
            build_number : env.BUILD_NUMBER as Integer,
            pipeline_id  : params.PIPELINE_ID ? params.PIPELINE_ID as Long : 0,
            stage_type   : stageType,
            status       : status
        ]

        def body = groovy.json.JsonOutput.toJson(payload)
        def stageUrl = params.PLATFORM_CALLBACK_URL.replace('/callback', '/stage/callback')

        def signature = ''
        if (env.HMAC_SECRET?.trim()) {
            def signContent = "${env.JOB_NAME}:${env.BUILD_NUMBER}:${stageType}"
            signature = hmacSha256(env.HMAC_SECRET, signContent)
        }

        def headers = signature ? [[name: 'X-Signature', value: signature]] : []

        httpRequest(
            url: stageUrl,
            httpMode: 'POST',
            contentType: 'APPLICATION_JSON',
            requestBody: body,
            customHeaders: headers,
            validResponseCodes: '100:599',
            timeout: 10
        )

        echo "[阶段回调] ${stageType} -> ${status}"
    } catch (e) {
        echo "[阶段回调] 非致命错误: ${e.message}"
    }
}

// ==================== 最终回调函数 ====================
def callbackPlatform(String status, String message) {
    if (!params.PLATFORM_CALLBACK_URL?.trim()) {
        echo "未配置回调地址"
        return
    }

    def payload = [
        job_name          : env.JOB_NAME,
        build_number      : env.BUILD_NUMBER as Integer,
        status            : status,
        pipeline_id       : params.PIPELINE_ID ? params.PIPELINE_ID as Long : 0,
        image_url         : env.FULL_IMAGE ?: '',
        image_digest      : env.IMAGE_DIGEST ?: '',
        image_with_digest : env.IMAGE_WITH_DIGEST ?: '',
        git_commit        : env.GIT_COMMIT_SHORT ?: '',
        git_branch        : env.GIT_BRANCH_NAME ?: '',
        duration_sec      : currentBuild.duration ? (currentBuild.duration / 1000) as Integer : 0,
        message           : message,
        build_url         : env.BUILD_URL ?: ''
    ]

    def body = groovy.json.JsonOutput.toJson(payload)

    def signature = ''
    if (env.HMAC_SECRET?.trim()) {
        def signContent = "${env.JOB_NAME}:${env.BUILD_NUMBER}:${status}"
        signature = hmacSha256(env.HMAC_SECRET, signContent)
    }

    def headers = signature ? [[name: 'X-Signature', value: signature]] : []

    echo "[流水线回调] ${status}: ${message}"
    echo "[签名内容] ${env.JOB_NAME}:${env.BUILD_NUMBER}:${status}"

    httpRequest(
        url: params.PLATFORM_CALLBACK_URL,
        httpMode: 'POST',
        contentType: 'APPLICATION_JSON',
        requestBody: body,
        customHeaders: headers,
        validResponseCodes: '200:299',
        consoleLogResponseBody: true
    )
}

// ==================== HMAC-SHA256 ====================
def hmacSha256(String secret, String data) {
    def result = ''
    withEnv([
        "SIGN_SECRET=${secret}",
        "SIGN_DATA=${data}"
    ]) {
        result = sh(
            script: '''
                set +x
                printf "%s" "$SIGN_DATA" | openssl dgst -sha256 -hmac "$SIGN_SECRET" | awk '{print $2}'
            ''',
            returnStdout: true
        ).trim()
    }
    return result
}
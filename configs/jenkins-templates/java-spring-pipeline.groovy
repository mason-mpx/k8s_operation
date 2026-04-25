// ==============================================================================
// K8s Operation Platform - Java/Spring Boot 通用构建模板
// ==============================================================================
// 设计理念：一个模板服务 100+ Java 项目，所有项目差异通过参数传入
// 支持框架：Spring Boot, Spring Cloud, 普通 Maven 项目
// 代码扫描：SonarQube 质量门禁集成（可选）
//
// ======================== Jenkins Job 配置方式 ========================
// 推荐使用 "Pipeline script from SCM"（版本化管理，自动同步更新）：
//
//   1. Jenkins → New Item → Pipeline → 命名为 k8s-builder-java
//   2. Pipeline 区域 → Definition 选择: Pipeline script from SCM
//   3. SCM 选择: Git
//   4. Repository URL: 填写平台仓库地址（如 https://gitee.com/your-org/k8s_operation.git）
//   5. Credentials: 选择 Git 凭证（如 gitee-id）
//   6. Branch Specifier: */main
//   7. Script Path: configs/jenkins-templates/java-spring-pipeline.groovy
//   8. 保存即可，后续模板更新自动生效
//
// 备选方式（直接粘贴脚本，不推荐）：
//   Pipeline → Definition: Pipeline script → 粘贴本文件内容
//
// ==============================================================================

pipeline {
    agent any

    options {
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(true)
    }

    parameters {
        string(name: 'GIT_REPO', defaultValue: '', description: 'Git 仓库地址（必填）')
        string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Git 分支')
        string(name: 'IMAGE_REPO', defaultValue: '', description: '镜像仓库地址（必填）')
        string(name: 'IMAGE_TAG', defaultValue: '', description: '镜像标签（空则自动生成）')
        string(name: 'DOCKERFILE_PATH', defaultValue: '', description: 'Dockerfile 路径（空则自动生成纯运行时 Dockerfile）')
        string(name: 'LANGUAGE_TYPE', defaultValue: '', description: '平台注入的语言类型（用于交叉校验，不要手动修改）')

        string(name: 'PIPELINE_ID', defaultValue: '', description: '平台流水线ID')
        string(name: 'RUN_ID', defaultValue: '', description: '平台运行记录ID')
        string(name: 'PLATFORM_CALLBACK_URL', defaultValue: '', description: '平台回调地址')
        string(name: 'ARTIFACT_UPLOAD_URL', defaultValue: '', description: '制品上传地址（平台制品库API）')

        // 构建参数
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: '跳过单元测试')
        string(name: 'JAVA_VERSION', defaultValue: '17', description: 'Java 版本')
        string(name: 'MAVEN_GOALS', defaultValue: 'clean package -DskipTests -B', description: 'Maven 构建命令')
        string(name: 'GIT_CREDENTIAL_ID', defaultValue: 'gitee-id', description: 'Git 凭证ID')

        // SonarQube 代码质量扫描参数
        booleanParam(name: 'ENABLE_SONAR', defaultValue: true, description: '启用 SonarQube 代码质量扫描')
        string(name: 'SONAR_PROJECT_KEY', defaultValue: '', description: 'SonarQube 项目 Key（空则使用 Job 名称）')
        string(name: 'SONAR_PROJECT_NAME', defaultValue: '', description: 'SonarQube 项目名称（空则使用 Job 名称）')
        string(name: 'SONAR_SOURCES', defaultValue: 'src/main/java', description: '源代码目录')
        string(name: 'SONAR_JAVA_BINARIES', defaultValue: 'target/classes', description: 'Java 编译输出目录')
        string(name: 'SONAR_EXCLUSIONS', defaultValue: '**/test/**,**/generated/**', description: '排除扫描的文件模式')
        booleanParam(name: 'SONAR_QUALITY_GATE', defaultValue: true, description: '启用质量门禁检查（不通过则构建失败）')
    }

    environment {
        REGISTRY_CREDS   = credentials('harbor-registry')
        HMAC_SECRET      = credentials('hmac-secret')
        MAVEN_OPTS       = '-Xmx1024m -Xms512m -XX:+TieredCompilation -XX:TieredStopAtLevel=1'
        MAVEN_LOCAL_REPO = "${env.WORKSPACE}/.m2/repository"
        // Maven 自动安装配置（服务器无 Maven 时自动下载）
        MAVEN_VERSION    = '3.9.9'
        MAVEN_INSTALL_DIR = '/var/lib/jenkins/tools/maven'
    }

    stages {

        stage('Clean Workspace') {
            steps {
                deleteDir()
                script {
                    // 语言类型交叉校验：防止自定义 Job 配错脚本
                    def expectedType = 'java'
                    def actualType = params.LANGUAGE_TYPE?.trim()
                    if (actualType && actualType != expectedType) {
                        def scriptMap = [
                            'go': 'go-pipeline.groovy',
                            'java': 'java-spring-pipeline.groovy',
                            'frontend': 'frontend-pipeline.groovy',
                            'python': 'python-pipeline.groovy'
                        ]
                        def correctScript = scriptMap[actualType] ?: "${actualType}-pipeline.groovy"
                        error("""
=== 模板类型不匹配 ===
平台配置语言类型: ${actualType}
当前模板类型: ${expectedType} (java-spring-pipeline.groovy)

解决方案（二选一）:
  1. 修改 Jenkins Job 的 Script Path 为: configs/jenkins-templates/${correctScript}
  2. 在平台将 Jenkins Job 名称留空，使用自动匹配
""")
                    }

                    if (!params.GIT_REPO?.trim()) { error("GIT_REPO 不能为空") }
                    if (!params.IMAGE_REPO?.trim()) { error("IMAGE_REPO 不能为空") }

                    def targetBranch = params.GIT_BRANCH?.trim() ?: 'main'
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "*/${targetBranch}"]],
                        extensions: [
                            [$class: 'CleanBeforeCheckout'],
                            [$class: 'LocalBranch', localBranch: targetBranch],
                            [$class: 'CloneOption', depth: 1, shallow: true, noTags: true, timeout: 10]
                        ],
                        userRemoteConfigs: [[url: params.GIT_REPO, credentialsId: params.GIT_CREDENTIAL_ID ?: 'gitee-id']]
                    ])
                    env.TARGET_BRANCH = targetBranch
                }
            }
        }

        stage('Checkout Info') {
            steps {
                script {
                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.GIT_COMMIT_FULL  = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.GIT_BRANCH_NAME  = (env.TARGET_BRANCH ?: 'main').replaceAll('/', '-')
                    env.BUILD_TS = sh(script: 'date +%Y%m%d%H%M%S', returnStdout: true).trim()
                    env.FINAL_TAG = params.IMAGE_TAG?.trim() ?: "${env.GIT_BRANCH_NAME}-${env.GIT_COMMIT_SHORT}-${env.BUILD_TS}"
                    env.FULL_IMAGE = "${params.IMAGE_REPO}:${env.FINAL_TAG}"
                    echo "Commit: ${env.GIT_COMMIT_SHORT} | Image: ${env.FULL_IMAGE}"
                }
            }
            post {
                success { script { stageCallback('checkout', 'success') } }
                failure { script { stageCallback('checkout', 'failed') } }
            }
        }

        // ==================== 构建工具自动检测与安装 ====================
        stage('Setup Build Tools') {
            steps {
                echo "=== 检测构建工具 ==="
                script {
                    // 1. 检测 Maven：mvnw → 系统 mvn → 自动下载
                    if (fileExists('mvnw')) {
                        sh 'chmod +x mvnw'
                        env.MVN_CMD = './mvnw'
                        echo "[Setup] 检测到 Maven Wrapper，使用 ./mvnw"
                    } else if (sh(script: 'which mvn 2>/dev/null', returnStatus: true) == 0) {
                        env.MVN_CMD = 'mvn'
                        echo "[Setup] 检测到系统 Maven: ${sh(script: 'mvn --version | head -1', returnStdout: true).trim()}"
                    } else {
                        echo "[Setup] Maven 未安装，自动下载 Maven ${MAVEN_VERSION}..."
                        def mavenDir = "${MAVEN_INSTALL_DIR}/apache-maven-${MAVEN_VERSION}"
                        def installed = sh(script: "test -x ${mavenDir}/bin/mvn && echo yes || echo no", returnStdout: true).trim()
                        if (installed != 'yes') {
                            sh """
                                set -e
                                mkdir -p ${MAVEN_INSTALL_DIR}
                                echo '[Setup] 下载 Maven (阿里云镜像)...'
                                curl -sSL https://mirrors.aliyun.com/apache/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \\
                                    | tar xz -C ${MAVEN_INSTALL_DIR}/
                                echo '[Setup] Maven 安装完成'
                            """
                        } else {
                            echo "[Setup] Maven 已缓存，跳过下载"
                        }
                        env.MVN_CMD = "${mavenDir}/bin/mvn"
                    }

                    // 2. 生成阿里云 Maven 镜像 settings.xml（加速依赖下载）
                    def settingsFile = "${env.WORKSPACE}/.m2/settings.xml"
                    sh "mkdir -p ${env.WORKSPACE}/.m2"
                    writeFile file: settingsFile, text: """\
<?xml version="1.0" encoding="UTF-8"?>
<settings>
  <mirrors>
    <mirror>
      <id>aliyun</id>
      <name>Aliyun Maven Mirror</name>
      <url>https://maven.aliyun.com/repository/public</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
</settings>
"""
                    env.MVN_SETTINGS = settingsFile
                    echo "[Setup] 已配置阿里云 Maven 镜像加速"

                    // 3. 检测 Java 版本
                    def javaVer = sh(script: 'java -version 2>&1 | head -1', returnStdout: true).trim()
                    echo "[Setup] Java: ${javaVer}"
                    sh "${env.MVN_CMD} --version | head -2"
                }
            }
            post {
                success { script { stageCallback('dependencies', 'success') } }
                failure { script { stageCallback('dependencies', 'failed') } }
            }
        }

        stage('Compile') {
            steps {
                echo "=== Maven 编译 ==="
                sh "${MVN_CMD} clean compile -DskipTests -B -T 1C -s ${MVN_SETTINGS} -Dmaven.repo.local=${MAVEN_LOCAL_REPO}"
            }
            post {
                success { script { stageCallback('compile', 'success') } }
                failure { script { stageCallback('compile', 'failed') } }
            }
        }

        stage('Test') {
            when { expression { return !params.SKIP_TESTS } }
            steps {
                echo "=== 单元测试 ==="
                sh "${MVN_CMD} test -B -T 1C -s ${MVN_SETTINGS} -Dmaven.repo.local=${MAVEN_LOCAL_REPO} -Dsurefire.useFile=false"
            }
            post {
                success { script { stageCallback('test', 'success') } }
                failure { script { stageCallback('test', 'failed') } }
                always { junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml' }
            }
        }

        // ==================== SonarQube 代码质量扫描 ====================
        stage('SonarQube Analysis') {
            when { expression { return params.ENABLE_SONAR } }
            steps {
                echo "=== SonarQube 代码质量扫描 ==="
                script {
                    def projectKey  = params.SONAR_PROJECT_KEY?.trim()  ?: env.JOB_NAME.replaceAll('/', '_')
                    def projectName = params.SONAR_PROJECT_NAME?.trim() ?: env.JOB_NAME
                    def sources     = params.SONAR_SOURCES?.trim()      ?: 'src/main/java'
                    def binaries    = params.SONAR_JAVA_BINARIES?.trim() ?: 'target/classes'
                    def exclusions  = params.SONAR_EXCLUSIONS?.trim()   ?: '**/test/**,**/generated/**'

                    withSonarQubeEnv('SonarQube') {
                        sh """
                            ${env.MVN_CMD} sonar:sonar \\
                                -s ${env.MVN_SETTINGS} \\
                                -Dsonar.projectKey=${projectKey} \\
                                -Dsonar.projectName=${projectName} \\
                                -Dsonar.projectVersion=${env.FINAL_TAG} \\
                                -Dsonar.sources=${sources} \\
                                -Dsonar.java.binaries=${binaries} \\
                                -Dsonar.exclusions=${exclusions} \\
                                -Dsonar.branch.name=${env.GIT_BRANCH_NAME} \\
                                -Dsonar.links.scm=${params.GIT_REPO} \\
                                -Dsonar.links.ci=${env.BUILD_URL} \\
                                -B
                        """
                    }
                    echo "[SonarQube] 扫描完成，等待质量门禁结果..."
                }
            }
            post {
                success { script { stageCallback('sonar', 'success') } }
                failure { script { stageCallback('sonar', 'failed') } }
            }
        }

        // ==================== SonarQube 质量门禁检查 ====================
        stage('Quality Gate') {
            when { expression { return params.ENABLE_SONAR && params.SONAR_QUALITY_GATE } }
            steps {
                echo "=== 质量门禁检查 ==="
                script {
                    // 等待 SonarQube 分析完成（最多 5 分钟）
                    def qg = waitForQualityGate()
                    env.SONAR_QUALITY_GATE_STATUS = qg.status
                    if (qg.status != 'OK') {
                        echo "[Quality Gate] 状态: ${qg.status}"
                        echo "[Quality Gate] 代码质量未达标，请登录 SonarQube 查看详细报告"
                        // 即使未通过也回传报告数据，让平台展示具体问题
                        sonarReportCallback(qg.status)
                        error("SonarQube Quality Gate 未通过: ${qg.status}")
                    }
                    echo "[Quality Gate] ✅ 通过！状态: ${qg.status}"
                    // 质量门禁通过后，将 SonarQube 指标数据回传平台
                    sonarReportCallback(qg.status)
                }
            }
            post {
                success { script { stageCallback('quality_gate', 'success') } }
                failure { script { stageCallback('quality_gate', 'failed') } }
            }
        }

        stage('Package') {
            steps {
                echo "=== 打包 ==="
                sh "${MVN_CMD} ${params.MAVEN_GOALS} -T 1C -s ${MVN_SETTINGS} -Dmaven.repo.local=${MAVEN_LOCAL_REPO}"
                archiveArtifacts artifacts: '**/target/*.jar', fingerprint: true, allowEmptyArchive: true
            }
            post {
                success { script { stageCallback('package', 'success') } }
                failure { script { stageCallback('package', 'failed') } }
            }
        }

        // ==================== 上传制品到平台制品库 ====================
        stage('Upload Artifact') {
            when { expression { return params.ARTIFACT_UPLOAD_URL?.trim() } }
            steps {
                echo "=== 上传构建产物到制品库 ==="
                script {
                    // 查找构建产物 JAR
                    def jarFile = sh(script: "find target -maxdepth 1 -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | head -1", returnStdout: true).trim()
                    if (!jarFile) {
                        echo "[制品库] 未找到 JAR 文件，跳过上传"
                        return
                    }
                    env.ARTIFACT_FILE = jarFile
                    def artifactName = jarFile.split('/')[-1]
                    echo "[制品库] 上传: ${artifactName}"

                    // 通过 curl 上传到平台制品库 API
                    def uploadResp = sh(
                        script: """
                            curl -s -X POST '${params.ARTIFACT_UPLOAD_URL}' \\
                                -F 'file=@${jarFile}' \\
                                -F 'pipeline_id=${params.PIPELINE_ID}' \\
                                -F 'run_id=${params.RUN_ID ?: ""}' \\
                                -F 'build_number=${env.BUILD_NUMBER}' \\
                                -F 'version=${env.FINAL_TAG}' \\
                                -F 'language_type=java' \\
                                -F 'artifact_type=jar' \\
                                -F 'git_repo=${params.GIT_REPO}' \\
                                -F 'git_branch=${env.GIT_BRANCH_NAME}' \\
                                -F 'git_commit=${env.GIT_COMMIT_FULL}'
                        """,
                        returnStdout: true
                    ).trim()
                    echo "[制品库] 上传响应: ${uploadResp}"
                }
            }
            post {
                success { script { stageCallback('upload_artifact', 'success') } }
                failure { script { stageCallback('upload_artifact', 'failed') } }
            }
        }

        // ==================== Docker 镜像构建（纯运行时，只打包 JAR） ====================
        stage('Build Image') {
            steps {
                echo "=== 构建 Docker 镜像（纯运行时，仅打包 JAR 制品） ==="
                script {
                    def dockerfile = params.DOCKERFILE_PATH?.trim()
                    def javaVersion = params.JAVA_VERSION ?: '17'

                    // 优先级：1) 参数指定路径 → 2) 项目自带 Dockerfile → 3) 自动生成
                    // __PLATFORM_GENERATE__ 为平台哨兵值，表示强制使用平台生成
                    def forceGenerate = (dockerfile == '__PLATFORM_GENERATE__')
                    if (!dockerfile || forceGenerate) {
                        // 智能检测模式：检查项目是否自带 Dockerfile（非强制生成时）
                        if (!forceGenerate && fileExists('Dockerfile')) {
                            dockerfile = 'Dockerfile'
                            echo "[Build Image] 检测到项目自带 Dockerfile，直接使用"
                        } else {
                            // 项目无 Dockerfile，自动生成纯运行时版本（阿里云镜像源）
                            dockerfile = '.Dockerfile.runtime'
                            writeFile file: dockerfile, text: """\
FROM registry.cn-hangzhou.aliyuncs.com/k8s-gos/java:${javaVersion}-jre-alpine
ENV TZ=Asia/Shanghai
WORKDIR /app
RUN addgroup -S appgroup && adduser -S -G appgroup appuser
RUN mkdir -p /app/logs && chown -R appuser:appgroup /app
COPY target/*.jar /app/app.jar
USER appuser
EXPOSE 8080
ENV JAVA_OPTS="\\
-XX:MaxRAMPercentage=75.0 \\
-XX:+UseG1GC \\
-XX:+HeapDumpOnOutOfMemoryError \\
-XX:HeapDumpPath=/app/logs \\
-Djava.security.egd=file:/dev/./urandom"
ENTRYPOINT ["sh", "-c", "exec java \$JAVA_OPTS -jar /app/app.jar"]
"""
                            echo "[Build Image] 项目无 Dockerfile，已自动生成纯运行时版本（阿里云 JRE 镜像）"
                        }
                    }

                    sh """
                        set -e
                        nerdctl build \\
                            -t ${env.FULL_IMAGE} \\
                            -f ${dockerfile} \\
                            --build-arg JAVA_VERSION=${javaVersion} \\
                            --label git.commit=${env.GIT_COMMIT_FULL} \\
                            --label git.branch=${env.GIT_BRANCH_NAME} \\
                            --label build.number=${env.BUILD_NUMBER} \\
                            --label artifact.version=${env.FINAL_TAG} \\
                            --label build.mode=platform-compile \\
                            .
                    """
                }
            }
            post {
                success { script { stageCallback('build', 'success') } }
                failure { script { stageCallback('build', 'failed') } }
            }
        }

        stage('Push Image') {
            steps {
                script {
                    def registryHost = params.IMAGE_REPO.split('/')[0]
                    sh """
                        set -e
                        echo \${REGISTRY_CREDS_PSW} | nerdctl login -u \${REGISTRY_CREDS_USR} --password-stdin ${registryHost}
                        nerdctl push ${env.FULL_IMAGE}
                    """
                    env.IMAGE_DIGEST = sh(
                        script: "nerdctl inspect ${env.FULL_IMAGE} --format '{{range .RepoDigests}}{{println .}}{{end}}' 2>/dev/null | grep -oE 'sha256:[a-f0-9]+' | head -1 || echo ''",
                        returnStdout: true
                    ).trim()
                    env.IMAGE_WITH_DIGEST = env.IMAGE_DIGEST ? "${params.IMAGE_REPO}@${env.IMAGE_DIGEST}" : env.FULL_IMAGE
                }
            }
            post {
                success { script { stageCallback('push', 'success') } }
                failure { script { stageCallback('push', 'failed') } }
            }
        }
    }

    post {
        success {
            script {
                def msg = params.ENABLE_SONAR
                    ? "Java 项目构建成功 | SonarQube: ${env.SONAR_QUALITY_GATE_STATUS ?: 'SKIPPED'}"
                    : 'Java 项目构建成功'
                callbackPlatform('SUCCESS', msg)
            }
        }
        failure { script { callbackPlatform('FAILURE', 'Java 项目构建失败') } }
        aborted { script { callbackPlatform('ABORTED', '构建中止') } }
        always { sh "nerdctl rmi ${env.FULL_IMAGE} || true"; cleanWs() }
    }
}

// ==================== 回调函数（与 Go 模板完全一致） ====================
def stageCallback(String stageType, String status) {
    if (!params.PLATFORM_CALLBACK_URL?.trim()) return
    try {
        def payload = [job_name: env.JOB_NAME, build_number: env.BUILD_NUMBER as Integer,
            pipeline_id: params.PIPELINE_ID ? params.PIPELINE_ID as Long : 0, stage_type: stageType, status: status]
        def body = groovy.json.JsonOutput.toJson(payload)
        def stageUrl = params.PLATFORM_CALLBACK_URL.replace('/pipeline/callback', '/stage/callback')
        def signature = env.HMAC_SECRET?.trim() ? hmacSha256(env.HMAC_SECRET, "${env.JOB_NAME}:${env.BUILD_NUMBER}:${stageType}") : ''
        def headers = signature ? [[name: 'X-Signature', value: signature]] : []
        httpRequest(url: stageUrl, httpMode: 'POST', contentType: 'APPLICATION_JSON',
            requestBody: body, customHeaders: headers, validResponseCodes: '100:599', timeout: 10)
    } catch (e) { echo "[阶段回调] 非致命: ${e.message}" }
}

def callbackPlatform(String status, String message) {
    if (!params.PLATFORM_CALLBACK_URL?.trim()) { echo "未配置回调地址"; return }
    def payload = [job_name: env.JOB_NAME, build_number: env.BUILD_NUMBER as Integer, status: status,
        pipeline_id: params.PIPELINE_ID ? params.PIPELINE_ID as Long : 0,
        image_url: env.FULL_IMAGE ?: '', image_digest: env.IMAGE_DIGEST ?: '',
        image_with_digest: env.IMAGE_WITH_DIGEST ?: '', git_commit: env.GIT_COMMIT_SHORT ?: '',
        git_branch: env.GIT_BRANCH_NAME ?: '',
        duration_sec: currentBuild.duration ? (currentBuild.duration / 1000) as Integer : 0,
        message: message, build_url: env.BUILD_URL ?: '']
    def body = groovy.json.JsonOutput.toJson(payload)
    def signature = env.HMAC_SECRET?.trim() ? hmacSha256(env.HMAC_SECRET, "${env.JOB_NAME}:${env.BUILD_NUMBER}:${status}") : ''
    def headers = signature ? [[name: 'X-Signature', value: signature]] : []
    httpRequest(url: params.PLATFORM_CALLBACK_URL, httpMode: 'POST', contentType: 'APPLICATION_JSON',
        requestBody: body, customHeaders: headers, validResponseCodes: '200:299', consoleLogResponseBody: true)
}

// ==================== SonarQube 指标回传平台 ====================
// 调用平台 sonar-callback 接口，将扫描结果持久化到运行记录中
def sonarReportCallback(String qualityGateStatus) {
    if (!params.PLATFORM_CALLBACK_URL?.trim()) return
    try {
        def projectKey = params.SONAR_PROJECT_KEY?.trim() ?: env.JOB_NAME.replaceAll('/', '_')
        def sonarUrl = params.PLATFORM_CALLBACK_URL.replace('/pipeline/callback', '/pipeline/sonar-callback')

        // 通过 SonarQube Web API 获取指标数据
        def metrics = [:]
        withSonarQubeEnv('SonarQube') {
            def apiUrl = "${env.SONAR_HOST_URL}/api/measures/component?component=${projectKey}&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,ncloc,security_hotspots,reliability_rating,security_rating,sqale_rating"
            def resp = httpRequest(url: apiUrl, httpMode: 'GET', validResponseCodes: '200', quiet: true)
            def json = readJSON text: resp.content
            json.component?.measures?.each { m ->
                metrics[m.metric] = m.value
            }
        }

        def payload = [
            pipeline_id:          params.PIPELINE_ID ? params.PIPELINE_ID as Long : 0,
            project_key:          projectKey,
            project_name:         params.SONAR_PROJECT_NAME?.trim() ?: env.JOB_NAME,
            quality_gate:         qualityGateStatus,
            dashboard_url:        "${env.SONAR_HOST_URL}/dashboard?id=${projectKey}",
            bugs:                 (metrics.bugs ?: '0') as Integer,
            vulnerabilities:      (metrics.vulnerabilities ?: '0') as Integer,
            code_smells:          (metrics.code_smells ?: '0') as Integer,
            coverage:             (metrics.coverage ?: '0.0') as Double,
            duplications:         (metrics['duplicated_lines_density'] ?: '0.0') as Double,
            lines_of_code:        (metrics.ncloc ?: '0') as Integer,
            security_hotspots:    (metrics.security_hotspots ?: '0') as Integer,
            reliability_rating:   ratingToLetter((metrics.reliability_rating ?: '1') as Double),
            security_rating:      ratingToLetter((metrics.security_rating ?: '1') as Double),
            maintainability_rating: ratingToLetter((metrics.sqale_rating ?: '1') as Double)
        ]

        def body = groovy.json.JsonOutput.toJson(payload)
        def signature = env.HMAC_SECRET?.trim() ? hmacSha256(env.HMAC_SECRET, "${env.JOB_NAME}:${env.BUILD_NUMBER}:sonar") : ''
        def headers = signature ? [[name: 'X-Signature', value: signature]] : []

        httpRequest(url: sonarUrl, httpMode: 'POST', contentType: 'APPLICATION_JSON',
            requestBody: body, customHeaders: headers, validResponseCodes: '100:599', timeout: 15)
        echo "[SonarQube] 指标数据已回传平台"
    } catch (e) {
        echo "[SonarQube] 指标回传非致命错误: ${e.message}"
    }
}

// SonarQube rating 数值转字母: 1.0=A, 2.0=B, 3.0=C, 4.0=D, 5.0=E
def ratingToLetter(Double rating) {
    if (rating <= 1.0) return 'A'
    if (rating <= 2.0) return 'B'
    if (rating <= 3.0) return 'C'
    if (rating <= 4.0) return 'D'
    return 'E'
}

def hmacSha256(String secret, String data) {
    def result = ''
    withEnv(["SIGN_SECRET=${secret}", "SIGN_DATA=${data}"]) {
        result = sh(script: 'set +x && printf "%s" "$SIGN_DATA" | openssl dgst -sha256 -hmac "$SIGN_SECRET" | awk \'{print $2}\'', returnStdout: true).trim()
    }
    return result
}

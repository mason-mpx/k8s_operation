# ============================================
# Java 项目 - 纯运行时 Dockerfile（平台编译模式）
# ============================================
# 设计理念：
#   - 不包含 Maven/Gradle 编译环境
#   - 仅接收平台 mvn package 产出的 JAR
#   - 使用 JRE 而非 JDK，镜像更小
#   - 生产级 JVM 参数调优
#
# 配合流水线使用：
#   Jenkins Package 阶段产出 target/*.jar
#   Build Image 阶段执行 nerdctl build
#
# 基础镜像说明：
#   使用阿里云镜像源，国内拉取更快
#   registry.cn-hangzhou.aliyuncs.com/k8s-gos/java:17-jre-alpine
# ============================================

ARG JAVA_VERSION=17
FROM registry.cn-hangzhou.aliyuncs.com/k8s-gos/java:${JAVA_VERSION}-jre-alpine

ENV TZ=Asia/Shanghai
WORKDIR /app

# 创建非 root 用户（Alpine 写法）
RUN addgroup -S appgroup && adduser -S -G appgroup appuser

# 创建日志目录并授权
RUN mkdir -p /app/logs && chown -R appuser:appgroup /app

# 复制 JAR（由流水线 Package 阶段产出）
COPY target/*.jar /app/app.jar

# 切换用户
USER appuser

EXPOSE 8080

# 生产级 JVM 参数（可通过环境变量 JAVA_OPTS 覆盖）
# - MaxRAMPercentage: 容器内存自适应，比固定 -Xmx 更适合 K8s
# - G1GC: 低延迟垃圾回收
# - HeapDump: OOM 时自动生成堆转储
# - GC Log: 便于生产排查
ENV JAVA_OPTS="\
-XX:MaxRAMPercentage=75.0 \
-XX:+UseG1GC \
-XX:+HeapDumpOnOutOfMemoryError \
-XX:HeapDumpPath=/app/logs \
-Xlog:gc*:file=/app/logs/gc.log:time,uptime,level \
-Djava.security.egd=file:/dev/./urandom"

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]

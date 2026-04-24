# ============================================
# Java 项目 - 纯运行时 Dockerfile（平台编译模式）
# ============================================
# 设计理念：
#   - 不包含 Maven/Gradle 编译环境
#   - 仅接收平台 mvn package 产出的 JAR
#   - 使用 JRE 而非 JDK，镜像更小
#   - 支持 JVM 参数调优
#
# 配合流水线使用：
#   Jenkins Package 阶段产出 target/*.jar
#   Build Image 阶段执行 nerdctl build --build-arg JAVA_VERSION=17
# ============================================

ARG JAVA_VERSION=17
FROM eclipse-temurin:${JAVA_VERSION}-jre-alpine

# 安装时区
RUN apk --no-cache add tzdata wget && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# 创建非 root 用户
RUN addgroup -g 1000 -S app && \
    adduser -u 1000 -S app -G app

# 创建工作目录
WORKDIR /app
RUN mkdir -p /app/logs /app/config && \
    chown -R app:app /app

# 接收平台编译好的 JAR（由流水线 Package 阶段产出）
COPY target/*.jar app.jar
RUN chown app:app app.jar

USER app

EXPOSE 8080

# JVM 参数（可通过环境变量覆盖）
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/app/logs/"
ENV SPRING_PROFILES_ACTIVE=prod

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

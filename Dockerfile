# CICD系统 - 统一Docker镜像
FROM ruby:3.2-alpine

# 设置环境变量
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV RACK_ENV=production

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apk add --no-cache \
    sqlite \
    sqlite-dev \
    build-base \
    git \
    curl \
    && rm -rf /var/cache/apk/*

# 配置RubyGems镜像源
RUN gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/

# 安装必要的gems
RUN gem install sinatra sequel sqlite3 bcrypt json --no-document

# 安装完整功能gems（可选）
RUN gem install sinatra-flash haml sass --no-document || echo "Optional gems installation failed, will use simple mode"

# 复制主应用文件
COPY app.rb .

# 创建数据库目录
RUN mkdir -p /app

# 暴露端口
EXPOSE 4567

# 设置模式环境变量（可通过docker run -e CICD_MODE=full 覆盖）
ENV CICD_MODE=simple

# 启动命令
CMD ["ruby", "app.rb"]
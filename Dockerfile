# 使用官方Ruby镜像作为基础
FROM ruby:3.2-slim-bullseye

# 设置工作目录
WORKDIR /app

# 安装必要的系统依赖
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    sqlite3 \
    libsqlite3-dev \
    curl && \
    rm -rf /var/lib/apt/lists/*

# 安装Bundler
RUN gem install bundler -v 2.4.22

# 复制Gemfile
COPY Gemfile ./

# 安装Ruby依赖（如果没有Gemfile.lock则自动生成）
RUN bundle install --jobs 4 --retry 3

# 复制应用代码
COPY . .

# 确保public目录存在并有正确权限
RUN mkdir -p public/images && \
    chmod -R 755 public

# 暴露端口
EXPOSE 4567

# 设置启动命令
CMD ["ruby", "app.rb"]
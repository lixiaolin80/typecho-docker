#!/bin/bash

MY_BLOG_DIR="/opt/myblog"

if [ "$(uname)" == "Darwin" ]; then
    MY_BLOG_DIR="/tmp/myblog"
else
    MY_BLOG_DIR="/opt/myblog"
fi

BLOG_DOMAIN="wp.pp.cool"
MYSQL_PASSWORD="d123b456"
DB_NAME="myblog_typecho"

ENABLE_SSL=false
SSL_CER_PATH=""
SSL_KEY_PATH=""

# 输入域名和数据库密码
get_input() {
    echo "输入绑定的域名(Please enter the domain): "
    read domain
    echo "输入数据库密码(Please enter db password): "
    read pass
}

# 定义函数，用于确认用户输入
confirm_input() {
    # 输出用户输入的信息
    echo "确认信息是否正确 (Please confirm the following information)?"
    echo "你输入的域名是 (domain is): $domain"
    echo "你输入的密码是 (dbpass is): $pass"
    # 询问用户是否确认信息
    while true; do
        echo "确认信息无误(Is the information correct)? [y/n]"
        read answer
        case $answer in
            [Yy]* ) break;;
            [Nn]* ) return 1;;
            * ) echo "(请输入y或者n)Please answer y or n.";;
        esac
    done
    return 0
}

while true; do
    get_input
    if confirm_input; then
        break
    else
        echo "(重新输入)Please re-enter your information"
    fi
done

# 是否启用ssl证书
enable_ssl() {
    while true; do
        read answer
        case $answer in
            [Yy]* ) break;;
            [Nn]* ) return 1;;
            * ) echo "(请输入y或者n)Please answer y or n.";;
        esac
    done
}

# 输入域名证书路径
get_ssl_path() {
    echo "输入证书cer路径(Please enter ssl.cer path ): "
    read path_ssl_cer

    while true; do
        if [ -f $path_ssl_cer ]; then
            echo "ssl.cer exists."
            SSL_CER_PATH=$path_ssl_cer
            break
        else
            echo "ssl.cer not exists. re-enter"
            read path_ssl_cer
        fi
    done

    echo "输入证书key路径(Please enter ssl.key path ): "
    read path_ssl_key

    while true; do
        if [ -f $path_ssl_key ]; then
            echo "ssl.key exists."
            SSL_KEY_PATH=$path_ssl_key
            break
        else
            echo "ssl.key not exists. re-enter"
            read path_ssl_key
        fi
    done
}

echo "是否启用ssl证书(enable ssl)? [y/n]"
while true; do
    if enable_ssl; then
        echo "启用ssl证书, 输入证书路径"
        ENABLE_SSL=true
        get_ssl_path
        break
    else
        ENABLE_SSL=false
        echo "你选择了不使用ssl证书"
        break
    fi
done

echo "你输入的证书是 (ssl.cer path is): $SSL_CER_PATH"
echo "你输入的证书是 (ssl.key path is): $SSL_KEY_PATH"

# 继续安装
echo "Continuing with installation..."

BLOG_DOMAIN=$domain
MYSQL_PASSWORD=$pass

rm -rf $MY_BLOG_DIR

docker rm -f myblog_nginx
docker rm -f myblog_php
docker rm -f myblog_mysql

mkdir -p $MY_BLOG_DIR

cd $MY_BLOG_DIR

git clone https://github.com/lixiaolin80/typecho-docker.git


# logs nginx
mkdir -p $MY_BLOG_DIR/typecho-docker/workdir/logs/nginx/default
mkdir -p $MY_BLOG_DIR/typecho-docker/workdir/logs/nginx/typecho
# logs php
mkdir -p $MY_BLOG_DIR/typecho-docker/workdir/logs/php
# logs mysql
mkdir -p $MY_BLOG_DIR/typecho-docker/workdir/logs/mysql

# mysql db
mkdir -p $MY_BLOG_DIR/typecho-docker/workdir/mysql

# 
rm -rf $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled
mkdir -p  $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled

cp $MY_BLOG_DIR/typecho-docker/conf/nginx/00-default.conf $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/00-default.conf
cp $MY_BLOG_DIR/typecho-docker/conf/nginx/01-typecho.conf $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf

cp $MY_BLOG_DIR/typecho-docker/docker-compose.yml.example $MY_BLOG_DIR/typecho-docker/docker-compose.yml


# 是否启用 ssl 证书
LISTEN_PORT_REPLACE=80
SSL_CER_REPLACE=""
SSL_KEY_REPLACE=""

if [ "$ENABLE_SSL" = true ]; then

    echo "ssl exists. enabled 443 and ssl."

    LISTEN_PORT_REPLACE="443 ssl"
    SSL_CER_REPLACE="ssl_certificate     /workdir/ssl/${BLOG_DOMAIN}/ssl.cer;"
    SSL_KEY_REPLACE="ssl_certificate_key /workdir/ssl/${BLOG_DOMAIN}/ssl.key;"

    mkdir -p $MY_BLOG_DIR/typecho-docker/workdir/ssl/${BLOG_DOMAIN}

    cp $SSL_CER_PATH $MY_BLOG_DIR/typecho-docker/workdir/ssl/${BLOG_DOMAIN}/ssl.cer
    cp $SSL_KEY_PATH $MY_BLOG_DIR/typecho-docker/workdir/ssl/${BLOG_DOMAIN}/ssl.key

    echo "server {"                                     >> $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    echo "    listen 80;"                               >> $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    echo "    listen [::]:80;"                          >> $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    echo ""                                             >> $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    echo "    server_name ${BLOG_DOMAIN};"              >> $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    echo "    return 301 https://\$host\$request_uri;"  >> $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    echo "}"                                            >> $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    # server {
    #     listen 80;
    #     listen [::]:80;

    #     server_name ${BLOG_DOMAIN};
    #     return 301 https://\$host\$request_uri;
    # }
else
    echo "ssl does not exist. enabled 80."
fi
# 是否启用 ssl 证书


if [ "$(uname)" == "Darwin" ]; then
    sed -i ".bak" "s|LISTEN_PORT_REPLACE|${LISTEN_PORT_REPLACE}|g"      $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    sed -i ".bak" "s|SSL_CERTIFICATE_REPLACE|${SSL_CER_REPLACE}|g"      $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    sed -i ".bak" "s|SSL_CERTIFICATE_KEY_REPLACE|${SSL_KEY_REPLACE}|g"  $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf

    sed -i ".bak" "s|SERVER_NAME_REPLACE|$BLOG_DOMAIN|g"                $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    sed -i ".bak" "s|MYSQL_ROOT_PASSWORD_REPLACE|$MYSQL_PASSWORD|g"     $MY_BLOG_DIR/typecho-docker/docker-compose.yml

    rm -rf $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf.bak
    rm -rf $MY_BLOG_DIR/typecho-docker/docker-compose.yml.bak

else
    sed -i        "s|LISTEN_PORT_REPLACE|${LISTEN_PORT_REPLACE}|g"      $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    sed -i        "s|SSL_CERTIFICATE_REPLACE|${SSL_CER_REPLACE}|g"      $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    sed -i        "s|SSL_CERTIFICATE_KEY_REPLACE|${SSL_KEY_REPLACE}|g"  $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf

    sed -i        "s|SERVER_NAME_REPLACE|$BLOG_DOMAIN|g"               $MY_BLOG_DIR/typecho-docker/conf/nginx/sites-enabled/01-typecho.conf
    sed -i        "s|MYSQL_ROOT_PASSWORD_REPLACE|$MYSQL_PASSWORD|g"     $MY_BLOG_DIR/typecho-docker/docker-compose.yml
fi


mkdir -p $MY_BLOG_DIR/typecho-docker/workdir/projects/$BLOG_DOMAIN

cd $MY_BLOG_DIR/typecho-docker/workdir/projects/$BLOG_DOMAIN/
wget -N https://github.com/typecho/typecho/archive/refs/tags/v1.2.1.tar.gz
tar zxf v1.2.1.tar.gz
mv typecho-1.2.1 typecho


TYPECHO_CODE_DIR=$MY_BLOG_DIR/typecho-docker/workdir/projects/$BLOG_DOMAIN/typecho

echo "User-agent: *" >  $TYPECHO_CODE_DIR/robots.txt
echo "Disallow: /"   >> $TYPECHO_CODE_DIR/robots.txt

cd $MY_BLOG_DIR/typecho-docker

sleep 1
docker-compose up -d
sleep 1

# 等待 MySQL 容器启动
echo "Waiting for MySQL container to start..."
sleep 3

# until docker exec -i myblog_mysql mysqladmin ping --silent &> /dev/null; do
until docker exec -i myblog_mysql mysql -uroot -p${MYSQL_PASSWORD} -e "SELECT 1;" &> /dev/null; do
    echo "MySQL container is not ready yet. Waiting..."
    sleep 1
done

# 创建数据库
echo "Creating database..."
if docker exec -i myblog_mysql mysql -uroot -p${MYSQL_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"; then
    echo "Database '${DB_NAME} created successfully."
else
    echo "Failed to create database ${DB_NAME}."
    exit 1
fi

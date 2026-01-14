#!/bin/bash

# 1. Load biến môi trường
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Lỗi: Không tìm thấy file .env. Copy từ .env.example đi mày."
    exit 1
fi

echo "--- Đang kiểm tra hệ thống cho container: $DB_CONTAINER_NAME ---"

# 2. Kiểm tra Port có bị chiếm dụng không
PORT_CHECK=$(lsof -i -P -n | grep LISTEN | grep :$DB_PORT_EXTERNAL)
if [ ! -z "$PORT_CHECK" ]; then
    echo "Lỗi: Port $DB_PORT_EXTERNAL đã có thằng khác dùng rồi:"
    echo "$PORT_CHECK"
    exit 1
fi

# 3. Tạo folder data nếu chưa có
if [ ! -d "data" ]; then
    mkdir -p data
    echo "Đã tạo folder data."
fi

# 4. Triển khai
echo "Đang pull image và khởi chạy container..."
docker-compose up -d

# 5. Thông báo kết quả
if [ $? -eq 0 ]; then
    echo "-------------------------------------------------------"
    echo "DEPLOY THÀNH CÔNG!"
    echo "Container: $DB_CONTAINER_NAME"
    echo "IP/Port: $DB_HOST_IP:$DB_PORT_EXTERNAL"
    echo "DB Name: $DB_NAME"
    echo "-------------------------------------------------------"
    echo "Lưu ý: Nếu đây là lần đầu, đợi vài giây để nó chạy schema.sql trong /init."
else
    echo "Lỗi: Deploy thất bại. Kiểm tra log bằng docker logs $DB_CONTAINER_NAME"
fi
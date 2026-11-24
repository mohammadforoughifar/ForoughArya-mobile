FROM nginx:1.27-alpine

# حذف تنظیمات پیش‌فرض و کپی پیکربندی بهینه‌شدهٔ iOS PWA
RUN rm -f /etc/nginx/conf.d/default.conf
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf

# کپی تمام فایل‌های بیلدشدهٔ وب‌اپلیکیشن
COPY . /usr/share/nginx/html/
RUN rm -rf /usr/share/nginx/html/deploy /usr/share/nginx/html/web.config

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

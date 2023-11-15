# Use the official Nginx base image
FROM nginx:latest

# Copy a custom default Nginx configuration file
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Set the default response when accessing the root URL
RUN echo "hello from nginx-ingress" > /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]


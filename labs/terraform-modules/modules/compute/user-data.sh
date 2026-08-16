#!/bin/bash

set -e

# Update package list
apt-get update -y

# Install Nginx
apt-get install -y nginx

# Enable Nginx at boot
systemctl enable nginx

# Start Nginx
systemctl start nginx

# Create a custom web page
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
<title>Terraform Lab</title>
<style>
body {
    background-color:#f5f5f5;
    font-family: Arial;
    text-align:center;
    margin-top:100px;
}
h1 {
    color:#0066cc;
}
</style>
</head>
<body>

<h1>Terraform Infrastructure Lab</h1>

<h2>User Data Executed Successfully</h2>

<p>Provisioned by Terraform</p>

<p>Configured by Cloud-Init</p>

<p>Nginx Web Server Running</p>

</body>
</html>
EOF
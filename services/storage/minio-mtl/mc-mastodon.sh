#!/bin/sh
mc alias set region2 https://region2.io.example.com:443 accessKey secretKey
mc alias set region1 http://minio1:9000 accessKey secretKey
mc mirror --watch --overwrite --remove region1/example-mastodon region2/example-mastodon
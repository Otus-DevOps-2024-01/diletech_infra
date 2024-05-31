#!/usr/bin/env python3
import os
import boto3

# Получение значений переменных окружения
endpoint_url = os.environ.get('S3_ENDPOINT_URL')
access_key_id = os.environ.get('AWS_ACCESS_KEY_ID')
secret_access_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
bucket_name = os.environ.get('S3_BUCKET_NAME')

# Проверка наличия всех необходимых переменных окружения
if None in (endpoint_url, access_key_id, secret_access_key, bucket_name):
    raise ValueError("Не все переменные окружения установлены.")

# Создание клиента S3
s3 = boto3.resource('s3',
    endpoint_url=endpoint_url,
    aws_access_key_id=access_key_id,
    aws_secret_access_key=secret_access_key)

# Получение бакета
bucket = s3.Bucket(bucket_name)

# Удаление всех версий объектов (работает и для неверсионированных бакетов)
bucket.object_versions.delete()

# Прерывание всех многократных загрузок, что также удаляет все части
for multipart_upload in bucket.multipart_uploads.iterator():
    # Части, которые в настоящее время находятся в процессе загрузки,
    # могут или не могут быть успешно завершены,
    # поэтому может потребоваться прервать многократную загрузку несколько раз.
    while len(list(multipart_upload.parts.all())) > 0:
        multipart_upload.abort()

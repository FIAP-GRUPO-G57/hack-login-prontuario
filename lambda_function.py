import json
import boto3
import os
import logging
import hmac
import hashlib
import base64


# Configuração do logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_secret_hash(username, client_id, client_secret):
    message = username + client_id
    dig = hmac.new(client_secret.encode('utf-8'), message.encode('utf-8'), hashlib.sha256).digest()
    return base64.b64encode(dig).decode()

def lambda_handler(event, context):
    client = boto3.client('cognito-idp')
    user_pool_id = os.environ['USER_POOL_ID']
    client_id = os.environ['CLIENT_ID']
    client_secret = os.environ['CLIENT_SECRET']
    
    username = event['username']
    password = event['password']
    secret_hash = get_secret_hash(username, client_id, client_secret)
    
    try:
        response = client.initiate_auth(
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters={
                'USERNAME': username,
                'PASSWORD': password,
                'SECRET_HASH': secret_hash
            },
            ClientId=client_id
        )
        logger.info("Resposta da autenticação: %s", response)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Login successful',
                'token': response['AuthenticationResult']['IdToken']
            })
        }
    except client.exceptions.NotAuthorizedException as e:
        logger.error("NotAuthorizedException: %s", e)
        return {
            'statusCode': 401,
            'body': json.dumps({'message': 'The username or password is incorrect'})
        }
    except client.exceptions.UserNotConfirmedException as e:
        logger.error("UserNotConfirmedException: %s", e)
        return {
            'statusCode': 401,
            'body': json.dumps({'message': 'User is not confirmed'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }

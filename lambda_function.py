import json
import boto3
import os

def lambda_handler(event, context):
    client = boto3.client('cognito-idp')
    user_pool_id = os.environ['USER_POOL_ID']
    client_id = os.environ['CLIENT_ID']
    
    username = event['username']
    password = event['password']
    
    try:
        response = client.initiate_auth(
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters={
                'USERNAME': username,
                'PASSWORD': password
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
    except client.exceptions.NotAuthorizedException:
        logger.error("NotAuthorizedException: %s", e)
        return {
            'statusCode': 401,
            'body': json.dumps({'message': 'The username or password is incorrect'})
        }
    except client.exceptions.UserNotConfirmedException:
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

const amplifyconfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify/cli",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "ap-south-1_ybxclrVkJ",
            "AppClientId": "40bdcbv5gfpjkjub33kdhva35h",
            "Region": "ap-south-1"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "usernameAttributes": ["EMAIL"],
            "signupAttributes": ["EMAIL"],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": [
                "REQUIRES_LOWERCASE",
                "REQUIRES_UPPERCASE",
                "REQUIRES_NUMBERS"
              ]
            }
          }
        }
      }
    }
  }
}''';

graph TD
    User[Flutter Web Dashboard] -->|HTTPS| API[API Gateway]
    API --> Grade[Grade Function]
    API --> AI[AI Grade Function]
    API --> Route[Route Function]
    
    Grade --> Dynamo[(DynamoDB)]
    AI --> S3[(S3 Photos)]
    AI --> Bedrock[Amazon Bedrock]
    Route --> Dynamo
    
    style AI fill:#f96,stroke:#333
    style Grade fill:#69f,stroke:#333

    2. Technical StackLayerTechnologyAuthenticationAWS Amplify + CognitoFrontendFlutter (Web/Mobile)BackendNode.js 20 LambdaDatabaseDynamoDBAI/VisionAmazon Bedrock (Nova Lite)StorageS3 (Presigned URLs)3. Data Management: Identity-Bound StrategyWe utilize a userId-partitioned architecture to ensure privacy.Evaluations Table: Partitioned by evaluationId with a userId-createdAt-index GSI.Privacy: Data is scoped at the infrastructure level using Cognito claims, ensuring user history remains isolated and secure.4. API SurfaceEndpointMethodDescription/upload-urlPOSTGenerates presigned S3 PUT URL/gradePOSTPrice normalization & record creation/ai-gradePOSTVision-based condition grading/routePOSTLogistics distance & routing logic5. Pipeline StagesIngestion: Flutter triggers /upload-url to get an S3 target, then uploads photos directly.Gateway: /grade classifies intent (Amazon Return vs. Trade-in) and normalizes pricing.Inference: /ai-grade passes photos to Bedrock Nova to derive condition, conditionReason, and estimatedResaleValue.Routing: /route calculates the optimal disposition (Resell/Refurbish/Recycle) using Haversine logistics math.

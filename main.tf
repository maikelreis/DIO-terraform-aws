provider "aws" {
    region = "us-east-2"
    access_key = "{secrets.AWS_ACCESS_KEY}"
    secret_key = "{secrets.AWS_SECRET_KEY}"
}

resource "aws_dynamodb_table" "ddbtable" {
    name = "DIOLivePerson"
    hash_key = "id"
    billing_mode = "PROVISIONED"
    read_capacity = 5
    write_capacity = 5
    attribute {
      name = "id"
      type = "S"
    }
}

resource "aws_iam_role_policy" "write_policy" {
    name = "lambda_write_policy"
    role = aws_iam_role.registerRole.id
    policy = file("./registerRole/write_policy.json")
}

resource "aws_iam_role_policy" "read_policy" {
    name = "lambda_read_policy"
    role = aws_iam_role.getRole.id
    policy = file("./getRole/read_policy.json")
  
}

resource "aws_iam_role" "registerRole" {
    name = "registerPersonRole"
    assume_role_policy = file("./registerRole/assume_write_role_policy.json")

}

resource "aws_iam_role" "getRole" {
    name = "getPerson"
    assume_role_policy = file("./getRole/assume_write_role_policy.json")

}

resource "aws_lambda_function" "registerLambda" {
    function_name = "registerLambda"
    s3_bucket = "msr-dio-terraform"
    s3_key = "registerperson.zip"
    role = aws_iam_role.registerRole.arn
    handler = "registerPerson.handler"
    runtime = "nodejs18.x"
}

resource "aws_lambda_function" "getLambda" {
    function_name = "getLambda"
    s3_bucket = "msr-dio-terraform"
    s3_key = "getperson.zip"
    role = aws_iam_role.getRole.arn
    handler = "getPerson.handler"
    runtime = "nodejs18.x"
}

resource "aws_api_gateway_rest_api" "apiLambda" {
    name = "terraAPI-live"

}

resource "aws_api_gateway_resource" "writeResource" {
    rest_api_id = aws_api_gateway_rest_api.apiLambda.id
    parent_id = aws_api_gateway_rest_api.apiLambda.root_resource_id
    path_part = "insert"
}

resource "aws_api_gateway_method" "writeMethod" {
  depends_on = [aws_api_gateway_resource.writeResource]
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  resource_id = aws_api_gateway_resource.writeResource.id
  http_method = "POST"
  authorization = "NONE"
}


resource "aws_api_gateway_resource" "readResource" {
    rest_api_id = aws_api_gateway_rest_api.apiLambda.id
    parent_id = aws_api_gateway_rest_api.apiLambda.root_resource_id
    path_part = "getperson"

}

resource "aws_api_gateway_method" "readMethod" {
    depends_on = [aws_api_gateway_resource.readResource]
    rest_api_id = aws_api_gateway_rest_api.apiLambda.id
    resource_id = aws_api_gateway_resource.readResource.id
    http_method = "POST"
    authorization = "NONE"
}

resource "null_resource" "method-delay" {
  provisioner "local-exec" {
    command = "sleep 5"
  }
  triggers = {
    response = aws_api_gateway_resource.writeResource.id
  }
}


resource "aws_api_gateway_integration" "writeInt" {
    depends_on = [aws_api_gateway_method.writeMethod,
                    aws_api_gateway_resource.writeResource,
                    null_resource.method-delay]
    rest_api_id = aws_api_gateway_rest_api.apiLambda.id
    resource_id = aws_api_gateway_resource.writeResource.id
    http_method = aws_api_gateway_method.writeMethod.http_method 
    integration_http_method = "POST"
    type = "AWS_PROXY"
    uri = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/${aws_lambda_function.registerLambda.arn}/invocations"   
}

resource "aws_api_gateway_integration" "readInt" {
    depends_on = [aws_api_gateway_method.readMethod,
                    aws_api_gateway_resource.readResource,
                    null_resource.method-delay]
    rest_api_id = aws_api_gateway_rest_api.apiLambda.id
    resource_id = aws_api_gateway_resource.readResource.id
    http_method = aws_api_gateway_method.readMethod.http_method
    integration_http_method = "POST"
    type = "AWS_PROXY"
    uri = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/${aws_lambda_function.getLambda.arn}/invocations"

}

resource "aws_api_gateway_deployment" "apideploy" {
    depends_on = [ aws_api_gateway_integration.writeInt, aws_api_gateway_integration.readInt]
    rest_api_id = aws_api_gateway_rest_api.apiLambda.id
    description  = "Initial deployment"
    
}

resource "aws_api_gateway_stage" "dev" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.apiLambda.id
  deployment_id = aws_api_gateway_deployment.apideploy.id
}

#permissions

resource "aws_lambda_permission" "writePermission" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.registerLambda.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.apiLambda.execution_arn}/${aws_api_gateway_stage.dev.stage_name}/POST/insert"

}


resource "aws_lambda_permission" "readPermission" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.getLambda.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.apiLambda.execution_arn}/${aws_api_gateway_stage.dev.stage_name}/POST/getperson"
}

output "base_url" {
    value = aws_api_gateway_deployment.apideploy
}

output "write_method_http" {
  value = aws_api_gateway_method.writeMethod.http_method
}
function SVT-AuthHeaders ($SVTovc, $SVTuser, $SVTpass) {
   # Authenticate - Get SVT Access Token
   $uri = "https://" + $SVTovc + "/api/oauth/token"
   $base64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))
   $body = @{username="$SVTuser";password="$SVTpass";grant_type="password"}
   $headers = @{}
   $headers.Add("Authorization", "Basic $base64") 
   $response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post 
   $atoken = $response.access_token
   $headers = @{}
   $headers.Add("Authorization", "Bearer $atoken")
   return ,$headers
}

$restHeaders = SVT-AuthHeaders($ovc, $username, $pass)

# Input bindings are passed in via param block.
param($Timer)

$GithubToken = $env:GithubToken
$url = $env:SlackUrl

$repository = "MicrosoftDocs/azure-stack-docs"
$header = @{
    "Authorization" = "token " + $GithubToken
}

function Get-GitHubLatestUpdateDate {
    param (
        [parameter(mandatory = $true)][String]$filename
    )
    
    $LatestUpdateDate = "https://api.github.com/repos/$repository/commits?path=$filename"

    $res = Invoke-RestMethod -Method GET -Uri $LatestUpdateDate -Headers $header
    return $res.commit.committer[0].date
}

function Get-GitHubLatestCommit {

    $LatestCommit = "https://api.github.com/repos/$repository/commits"

    $res = Invoke-RestMethod -Method GET -Uri $LatestCommit -Headers $header
    return $res
}

function Get-GitHubTree {
    param (
        [parameter(mandatory = $true)][String]$sha
    )
    $LatestTree = "https://api.github.com/repos/$repository/git/trees/master?recursive=100"

    $res = Invoke-RestMethod -Method GET -Uri $LatestTree -Headers $header
    return $res
}

Write-output "Start!!!"

$AllFiles = New-Object System.Collections.ArrayList
$latestCommitSha = (Get-GitHubLatestCommit)[0].sha
$res = Get-GitHubTree -sha $latestCommitSha
$res.tree | ForEach-Object {
    if ($_.type -eq "blob"){
        if( $_.path -like "*.md"){
            $AllFiles.Add($_.path) | out-null
        }
    }
}

Write-output "Finished to list all files !!!"


$breakDate = (Get-Date).AddHours(-12)
$i = 1
$AllFiles | ForEach-Object {

    $file = $_
    Write-output "$i / $($AllFiles.Count)"
    $lastUpdateTime = Get-GitHubLatestUpdateDate -filename $file

    if ((Get-Date $lastUpdateTime) -ge $breakDate ) {

        $commitUrl = "https://github.com/$repository/commits/master/$file"

        $chatMessage = "Azs Doc Update: <$commitUrl|$file> "

        $body = @{
            "text"=$chatMessage
        } | ConvertTo-Json

        Write-output "Send a webhook : $body"
        Invoke-RestMethod -Method "POST" -Uri $url -Body $body


        Start-Sleep -Milliseconds 500
    }
    $i++
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

<#
.SYNOPSIS
    Merge open GitHub pull requests based on time and date validation.

.DESCRIPTION
    This script creates a GitHub Pull Request for each branch in a specified repository, excluding the default branch. It is triggered by an HTTP request and expects a JSON payload with the following properties:
    - BlogTitle: The title of the blog post.
    - PublishDay: The day the blog post will be published.
    - PublishTime: The time the blog post will be published.

    Required GitHub Fine-Grained Scope:
    - Contents [RW]
    - Pull Requests [RW]
    - Metadata [R]

    Required environment variables:
    - GITHUB_USER_TOKEN: A GitHub personal access token with the necessary permissions.
    - GITHUB_REPO_OWNER: The owner of the GitHub repository.
    - GITHUB_REPO_NAME: The name of the GitHub repository.

    The script uses the GitHub REST API to create the pull requests.

.NOTES
    File Name      : mergeGitHubPR.ps1
    Author         : https://twitter.com/smoon_lee
    Blog           : https://blog.builtwithcaffeine.cloud
#>

# Input bindings are passed in via param block.
param($Timer)

# # GitHub Repository Variables
$ghToken = $env:GITHUB_USER_TOKEN
$ghOwner = $env:GITHUB_REPO_OWNER
$ghRepository = $env:GITHUB_REPO_NAME

# GitHub API URIs and Headers
$ghOpenPullRequestUri = "https://api.github.com/repos/$ghOwner/$ghRepository/pulls?state=open"
$ghHeaders = @{
    Authorization = "Bearer $ghToken"
    Accept        = "application/vnd.github.v3+json"
}

# Function to parse JSON body for metadata
function Parse-JsonBody {
    param (
        [string]$body
    )

    $lines = $body -split "`r?`n"
    $publishDay = $null
    $publishTime = $null

    foreach ($line in $lines) {
        if ($line -match '^(.+?):\s*<code>(.+?)<\/code>(,|\s*$)') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            Write-Output "Key: $key, Value: $value"

            switch ($key) {
                "PublishDay.." { $publishDay = $value }
                "PublishTime" { $publishTime = $value }
            }
        }
    }

    return @{
        PublishDay  = $publishDay
        PublishTime = $publishTime
    }
}

# Function to add a comment to a GitHub Pull Request
function Add-GitHubPRMessage {
    param (
        [switch]$updatePR,
        [switch]$mergePR,
        [string]$number,
        [string]$postMetaDataDay,
        [string]$postMetaDataTime
    )

    $currentTime = Get-Date -Format "HH:mm"
    $currentDay = Get-Date -Format "dddd"

    Write-Output `r "Current Day: $currentDay"
    Write-Output "Current Time: $currentTime"
    Write-Output "PostMetaData Day: $postMetaDataDay"
    Write-Output "PostMetaData Time: $postMetaDataTime" `r

    $commentBody = if ($updatePR) {
        $triggerTime = Get-Date -Format "HH:mm:ss"
        @{
            body = "**[hugoScheduler] - mergeGitHubPR Function** `nFunction Trigger Time: $triggerTime `n`n**Post Validation Failed** `n`nCurrent Day: <code>$currentDay</code> `nCurrent Time: <code>$currentTime</code> `n`nPost Day: <code>$postMetaDataDay</code> `nPost Time: <code>$postMetaDataTime</code> `n`nhugoScheduler will check again later!"
        }
    }
    elseif ($mergePR) {
        $triggerTime = Get-Date -Format "HH:mm:ss"
        @{
            body = "**[hugoScheduler] - mergeGitHubPR Function** `nFunction Trigger Time: $triggerTime `n`n**Post Validation Passed** `n`nPost Day: <code>$postMetaDataDay</code> `nPost Time: <code>$postMetaDataTime</code> `n`nMerging PR Now!"
        }
    }

    $jsonBody = $commentBody | ConvertTo-Json
    $uri = "https://api.github.com/repos/$ghOwner/$ghRepository/issues/$number/comments"
    $null = Invoke-WebRequest -Method Post -Uri $uri -Headers $ghHeaders -ContentType "application/json" -Body $jsonBody

    Write-Output "Added comment to PR: $number"
}

# Function to close (merge) a GitHub Pull Request
function Close-GitHubPR {
    param (
        [string]$number
    )

    $jsonBody = @{
        merge_method   = "merge"
        commit_title   = "Merged PR #$number"
        commit_message = "[LGTM]"
    } | ConvertTo-Json

    $uri = "https://api.github.com/repos/$ghOwner/$ghRepository/pulls/$number/merge"
    $null = Invoke-WebRequest -Method Put -Uri $uri -Headers $ghHeaders -ContentType "application/json" -Body $jsonBody

    Write-Output "Merging PR: $number, GitHub Action warmup!"
}

# Fetch open pull requests
$githubOpenPRResponse = Invoke-WebRequest -Method Get -Uri $ghOpenPullRequestUri -Headers $ghHeaders -ContentType "application/json"
$pullRequests = $githubOpenPRResponse.Content | ConvertFrom-Json

# Check for open pull requests
if ($pullRequests.Count -eq 0) {
    Write-Output "No Pending Pull Requests, You might want to Blog again soon??"
    Exit 1
}

# Process each pull request
$currentDay = Get-Date -Format "dddd"
$currentTime = Get-Date -Format "HH:mm"
Write-Output "> [$currentDay] :: Open Pull Requests:`r"

foreach ($pullRequest in $pullRequests) {
    $number = $pullRequest.number
    $title = $pullRequest.title
    $body = $pullRequest.body

    Write-Output "Pull Request Number: $number"
    Write-Output "Pull Request Title: $title"

    $postMetaData = Parse-JsonBody -body $body
    Write-Output "Post Day: $($postMetaData.PublishDay)"
    Write-Output "Publish Time: $($postMetaData.PublishTime)" `r
}

foreach ($pullRequest in $pullRequests) {
    $number = $pullRequest.number
    $title = $pullRequest.title
    $body = $pullRequest.body
    $postMetaData = Parse-JsonBody -body $body

    Write-Output "Checking Pull Request MetaData: $title" `r

    if ($postMetaData.PublishTime -eq 'Now' -or ($postMetaData.PublishDay -eq $currentDay -and $postMetaData.PublishTime -eq $currentTime)) {
        Write-Output "DEBUG: -eq NOW"
        Add-GitHubPRMessage -mergePR -postMetaDataDay $postMetaData.PublishDay -postMetaDataTime $postMetaData.PublishTime -number $number
        Close-GitHubPR -number $number
    }
    else {
        Write-Output "DEBUG: -ne NOW"
        Add-GitHubPRMessage -updatePR -postMetaDataDay $postMetaData.PublishDay -postMetaDataTime $postMetaData.PublishTime -number $number
    }
}
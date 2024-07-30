<#
.SYNOPSIS
    Create GitHub Pull Requests for each branch in a repository.

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
    - GITHUB_DEFAULT_BRANCH: The default branch of the GitHub repository.

    The script uses the GitHub REST API to create the pull requests.

.NOTES
    File Name      : createGitHubPR.ps1
    Author         : https://twitter.com/smoon_lee
    Blog           : https://blog.builtwithcaffeine.cloud
#>

using namespace System.Net

param($Request, $TriggerMetadata)

# GitHub Repository Variables
$ghToken = $env:GITHUB_USER_TOKEN
$ghOwner = $env:GITHUB_REPO_OWNER
$ghRepository = $env:GITHUB_REPO_NAME
$ghDefaultBranch = $env:GITHUB_DEFAULT_BRANCH

# Validate required environment variables
if (-not $ghToken -or -not $ghOwner -or -not $ghRepository -or -not $ghDefaultBranch) {
    Write-Warning "Error: Missing required environment variables."
    exit 1
}

# GitHub API URIs
$ghRepositoryUri = "https://api.github.com/repos/$ghOwner/$ghRepository/branches"
$ghCreatePullRequestUri = "https://api.github.com/repos/$ghOwner/$ghRepository/pulls"
$ghHeaders = @{
    Authorization = "Bearer $ghToken"
    Accept        = "application/vnd.github.v3+json"
}

# Convert JSON Payload
try {
    $requestData = $Request.RawBody | ConvertFrom-Json
    $PublishDay = $requestData.PublishDay
    $PublishTime = $requestData.PublishTime
    $BlogTitle = $requestData.BlogTitle
}
catch {
    Write-Warning "Error: Invalid JSON payload."
    exit 1
}

# Verbose JSON Check
Write-Output `r "JSON Response Data:"
Write-Output "BlogTitle....: $BlogTitle"
Write-Output "PublishDay...: $PublishDay"
Write-Output "PublishTime..: $PublishTime" `r

# Send response back indicating the request was received
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = "Request Received, Awesome Work!"
    })

# Get Current GitHub Branches
try {
    $githubBranchesResponse = Invoke-WebRequest -Method Get -Uri $ghRepositoryUri -Headers $ghHeaders -ContentType "application/json"
    $githubBranches = $githubBranchesResponse.Content | ConvertFrom-Json
}
catch {
    Write-Warning "Error: Unable to fetch branches from GitHub."
    exit 1
}

# Filter out the default branch
$filteredBranches = $githubBranches | Where-Object { $_.name -ne $ghDefaultBranch }

# Create pull requests for each branch
foreach ($branch in $filteredBranches) {
    $sourceBranch = $branch.name
    $pullRequestData = @{
        title = "[AzFunction] - New Blog Post: $BlogTitle"
        body  = "PublishDay: $PublishDay,`nPublishTime: $PublishTime"
        head  = $sourceBranch
        base  = $ghDefaultBranch
    }

    # Convert data to JSON
    $pullRequestJson = $pullRequestData | ConvertTo-Json

    # Attempt to create pull request
    try {
        $createPullRequestResponse = Invoke-WebRequest -Method Post -Uri $ghCreatePullRequestUri -Headers $ghHeaders -Body $pullRequestJson -ContentType "application/json"
        $pullRequestInfo = $createPullRequestResponse.Content | ConvertFrom-Json
        $pullRequestNumber = $pullRequestInfo.number
        Write-Output `r "Pull Request [#$pullRequestNumber] created: $sourceBranch." `r
    }
    catch {
        Write-Warning "Error: Unable to create pull request for branch: $sourceBranch."
    }
}
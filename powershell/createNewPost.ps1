<#
.SYNOPSIS
    Creates a new post for a Hugo website and sets up the necessary files and folders.

.DESCRIPTION
    This script creates a new post for a Hugo website by generating a new Markdown file and setting up the required folder structure. It also creates a new Git branch for the post.

.PARAMETER environment
    Specifies the environment for the Hugo website. Valid values are "prod" for production and "dev" for development.

.PARAMETER newPost
    Specifies the name of the new post.

.EXAMPLE
    createNewPost.ps1 -environment prod -newPost "my-new-post"
    Creates a new post with the name "my-new-post" in the production environment.

.EXAMPLE
    createNewPost.ps1 -environment dev -newPost "my-dev-post"
    Creates a new post with the name "my-dev-post" in the development environment.

.NOTES
File Name      : publishPost.ps1
Author         : Simon Lee - GitHub: @smoonlee - Twitter: @smoon_lee
Prerequisite   : Git installed, Hugo configured
#>

param (
    [string] [Parameter (Mandatory = $true)] [ValidateSet("prod", "dev")] $environment,
    [string] [Parameter (Mandatory = $true)] $newPost
)

if (-not(hugo)) {
    Write-Output "Hugo is not installed. Please install Hugo and try again."
}

# Built With Caffeine Environments
switch ($environment) {
    'prod' {
        $hugoSourcePath = '<production-hugo-path>'
    }
    'dev' {
        $hugoSourcePath = '<development-hugo-path>'
    }
}

$datePrefix = Get-Date -Format "yyyy-MM"
$hugoContentPath = "$hugoSourcePath\content\posts\$datePrefix-$newPost\index.md"

Write-Output "Creating new post: $datePrefix-$newPost"
Write-Output "Creating Git Branch: post/$datePrefix-$newPost"

# Set Location and Create Git Branch
Set-Location -Path $hugoSourcePath
git checkout -b "post/$datePrefix-$newPost"

# Hugo Create default post
hugo new content $hugoContentPath

# Change Draft State to True
$postContent = Get-Content -Path $hugoContentPath
$postContent | ForEach-Object { $_ -replace "draft = true", "draft = false" } | Set-Content $hugoContentPath

# Create assets folder
Write-Output "Creating Assets Folder: $hugoSourcePath\content\posts\$datePrefix-$newPost\assets"
New-Item -ItemType 'Directory' -Path "$hugoSourcePath\content\posts\$datePrefix-$newPost\assets" | Out-Null
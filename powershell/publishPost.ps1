<#
.SYNOPSIS
Publishes a blog post and creates a pull request for the post.

.DESCRIPTION
This script is used to publish a blog post and create a pull request for the post. It takes the day of the week and time for publishing as input parameters. It also allows specifying a commit message for the new post.

.PARAMETER PublishDay
Specifies the day of the week for publishing the blog post. Valid values are Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, and Sunday.

.PARAMETER PublishTime
Specifies the time for publishing the blog post. Valid values are Now, 08:00, 09:00, 10:00, 11:00, 12:00, 13:00, 14:00, and 15:00.

.PARAMETER CommitMessage
Specifies a commit message for the new post. If not provided, it defaults to "[new post] - <current branch name>".

.EXAMPLE
publishPost.ps1 -PublishDay Monday -PublishTime 10:00 -CommitMessage "Added new blog post"

This example publishes a blog post on Monday at 10:00 and uses the specified commit message.

.NOTES
File Name      : publishPost.ps1
Author         : Simon Lee - GitHub: @smoonlee - Twitter: @smoon_lee
Prerequisite   : Git installed, Hugo configured

#>

param (
    [Parameter(
        Mandatory = $true,
        Position = 0,
        HelpMessage = "Specify the day of the week for publishing (e.g., Monday).")]
    [ValidateSet("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")]
    [string]$PublishDay,

    [Parameter(
        Mandatory = $true,
        Position = 1,
        HelpMessage = "Specify the time for publishing (e.g., 10:00 GMT).")]
    [ValidateSet("Now", "08:00", "08:30", "09:00", "09:30", "10:00", "10:30", "11:00", "11:30", "12:00", "12:30", "13:00", "13:30", "14:00", "14:30", "15:00", "15:30", "16:00", "16:30", "17:00", "17:30", "18:00", "18:30", "19:00", "19:30", "20:00", "20:30", "21:00", "21:30", "22:00", "22:30", "23:00", "23:30", "00:00")]
    [string]$PublishTime,

    [Parameter(
        Position = 2,
        HelpMessage = "Enter a commit message for the new post.")]
    [string]$CommitMessage = "[new post] - $(git rev-parse --abbrev-ref HEAD)"
)

# Clean Console
Clear-Host

try {
    # Display parameters
    Write-Output `r "Hugo - Blog Post Publisher"`r
    Write-Output "Publish Day...: $PublishDay"
    Write-Output "Publish Time..: $PublishTime"
    Write-Output "Commit Message: $CommitMessage"

    # Git Push
    Write-Output `r "[Script] :: Adding new Post to Commit!"`r
    $folderName = $(git rev-parse --abbrev-ref HEAD).Trim('post/')
    git add ./content/posts/$folderName/* ; git commit -m $CommitMessage

    Write-Output `r "[Script] :: Pushing Post to Git"`r
    git push

}
catch {
    Write-Output "[Error] :: An error occurred: $_"
}

Write-Output `r "[Script] :: Creating Pull Request for Post"`r

# Create a custom object with the relevant information
$outputObject = [PSCustomObject]@{
    BlogTitle   = $CommitMessage -replace '\[new post\] - feature/', ''
    PublishDay  = $PublishDay
    PublishTime = $PublishTime
}

# Convert the object to JSON
$outputJson = $outputObject | ConvertTo-Json

# Output the JSON
Write-Output "Json Payload:"
Write-Output $outputJson

$azFuncUri = "<azure-function-url-here>"
$azFuncResponse = Invoke-WebRequest -Method Post -Uri $azFuncUri -Body $outputJson -ContentType "application/json"
Write-Output `r "Response from azure Function: $azFuncResponse"

Write-Output `r "[Script] :: azure Function, Executing Scheduling..."
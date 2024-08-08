<#
.SYNOPSIS
Checks if the project name is exactly 5 characters long.

.DESCRIPTION
This function takes a project name as input and checks if it is exactly 5 characters long. If the project name is not 5 characters long, an exception is thrown.

.PARAMETER projectName
The project name to be checked.

.EXAMPLE
checkProjectName -projectName "MyProj"
This example checks if the project name "MyProj" is exactly 5 characters long.

#>
function checkProjectName{
    param (
        [string]$projectName
    )

    if ($projectName.Length -gt '5') {
        throw "The Project Name has a maximum length of 5 characters, Sorry! try again."
    }
}
param
(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $testResultsFile,

    [switch] $uploadResults
)

# When rerunning manually, the previous test result file can cause
# PSScriptAnalyze to report false errors
if (Test-Path -Path $testResultsFile)
{
    Remove-Item $testResultsFile
}

try
{
    if ($error.Count -gt 0)
    {
        Write-Warning -Message '$error.count is not zero'
        $error.Clear()
    }

    Start-Transcript -Path '.\pester.transcript.txt'
    Write-Host 'Pester transcript written to .\pester.transcript.txt'
    try
    {
        $res = Invoke-Pester -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
    }
    finally
    {
        Stop-Transcript
    }
    if ($error.Count -gt 0)
    {
        Write-Warning -Message 'Pester leaked errors in $error'
    }

    if ($uploadResults)
    {
        (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
    }
}
catch
{
    $_ | select *
    throw $_
}


if ($res.FailedCount -gt 0)
{
    throw "$($res.FailedCount) tests failed."
}

if ($Error.Count -gt 0)
{
    Write-Warning  "Errors were detected in the error stream:"
    $error | select * | out-string

    $errors = $error.ToArray()
    foreach ($err in $errors)
    {
        $err | select * | out-string
        Write-Warning -Message "---------------------------"
    }
    throw "All tests passed but errors were found in the output stream"
}

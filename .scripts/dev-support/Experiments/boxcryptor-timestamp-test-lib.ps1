
function Create-TestFixture {
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [string]$encryptedDirPath,

        [Parameter(Mandatory=$True, Position=1)]
        [string]$testDirName
    )

    return [string](New-Item -ItemType Directory -Path "$encryptedDirPath\$testDirName")
}

function Get-FirstTimestamp {
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [string]$testFileName,

        [Parameter(Mandatory=$True, Position=1)]
        [string]$testFixture,

        [Parameter(Position=2)]
        [string]$sourceFilePath=""
    )

    if ( $sourceFilePath -eq "" ) {
        # Create a test file with arbitrary data.

        # Create content
        $randomSnippet="$([System.Guid]::NewGuid())"
        $sb = [System.Text.StringBuilder]::new()

        foreach( $i in 1..100000)
        {
            [void]$sb.Append( $randomSnippet )
        }

        $content=$sb.ToString()

        # Create file, return timestamp
        return (New-Item -Path "$testFixture" -Name "$testFileName" -ItemType File -Value "$content").LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff')
    } else {
        # Copy the provided file, return timestamp
        return (Copy-Item -PassThru -LiteralPath "$sourceFilePath" -Destination "$testFixture\$testFileName").LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff')
    }
}

function Get-FollowUpTimestamp {
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [string]$testFileName,

        [Parameter(Mandatory=$True, Position=1)]
        [string]$testFixture
    )
    
    return (Get-Item -LiteralPath "$testFixture\$testFileName").LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff')
}

---
external help file: posh-tex-help.xml
online version: http://www.cgranade.com/posh-tex/cmdlets/Get-PandocUserDir/
schema: 2.0.0
---

# Get-PandocUserDir

## SYNOPSIS
Finds the user data directory for Pandoc if it is installed.

## SYNTAX

```
Get-PandocUserDir [<CommonParameters>]
```

## DESCRIPTION
The **Get-PandocUserDir** cmdlet returns the path to the Pandoc user directory
if Pandoc is installed. This directory can be used to install user-specific resources such as
templates for converting between different document formats.

## EXAMPLES

### Example 1
```powershell
PS C:\> Get-PandocUserDir
C:\Users\<username>\AppData\Roaming\pandoc
```

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### String

This cmdlet returns a **String** specifying the Pandoc user directory.

## NOTES

## RELATED LINKS

[Pandoc](http://pandoc.org/)

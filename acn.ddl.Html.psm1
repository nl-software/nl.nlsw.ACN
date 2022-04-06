#	__ _ ____ _  _ _    _ ____ ____   ____ ____ ____ ___ _  _ ____ ____ ____
#	| \| |=== |/\| |___ | |--- |===   ==== [__] |---  |  |/\| |--| |--< |===
#
# @file acn.ddl.Html.psm1
# @copyright Ernst van der Pols, Licensed under the EUPL-1.2-or-later
#requires -version 5
#requires -modules nl.nlsw.Document

<#
.SYNOPSIS
 Convert an ACN DDL module to HTML with XSL-T.
 
.DESCRIPTION
 Convert an ACN DDL module to HTML using an Extensible Stylesheet Language
 Transformations (XSL-T) stylesheet.
 
.PARAMETER InputObject
 ACN DDL module directory or file(s) to convert to HTML. Wildcards accepted.

.PARAMETER OutPath
 Directory of the output file(s). By default equal to the directory of the input file.

.PARAMETER Extension
 File name extension of the output files, by default ".html".

.PARAMETER DefaultSheet
 File name of the default XSL-T stylesheet to use for the conversion.

.PARAMETER UseMsXsl
 Legacy emulation: use the msxsl.exe xslt processor instead of .NET

.INPUTS
 System.String - name of an ACN DDL module directory or file(s) to convert
 System.IO.FileSystemInfo - module directory or file(s) to convert

.OUTPUTS
 System.IO.FileInfo - resulting HTML file(s)

.EXAMPLE
 PS> "*.ddl.xml" | Convert-AcnModuleToHtml -outpath "../html"
 
 Convert the ACN DDL modules in the current directory to HTML in a parallel html folder.
 
.LINK
 https://www.w3.org/Style/XSL/

.NOTES
 @date 2022-03-21
 @author Ernst van der Pols
#>
function Convert-AcnModuleToHtml {
	[CmdletBinding()]
	param ( 
		[Parameter(Mandatory=$false, ValueFromPipeline = $true)]
		[object]$InputObject,

		[Parameter(Mandatory=$false)]
		[string]$OutPath,

		[Parameter(Mandatory=$false)]
		[string]$Extension = ".html",
		
		[Parameter(Mandatory=$false)]
		[string]$DefaultSheet = "$PSScriptRoot/../xsl/acn.ddl-to-html.xsl",

		[Parameter(Mandatory=$false)]
		[switch]$UseMsXsl
	)
	begin {
		if ($PSVersionTable.PSVersion.Major -lt 6) {
			# get rid of the UTF-16 encoding of output streams
			$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
		}
		$xsltparams = @{'filename-extension'=".ddl.html"}
		$xslt = $null
		$xsltdir = ""
		# targetpath determines the generated "path to other files", by default use single (same) folder
		$targetpath = "."

		if ($OutPath) {
			if (!(test-path $OutPath)) {
				# make sure the OutPath exists
				new-item -path $OutPath -type directory -force | out-null
			}
		}
		if ($targetpath -match '[^\\/]$') { 
			$targetpath += '/'
		}
		$xsltparams['target-path'] = $targetpath

		function New-CompiledSheet {
			param (
				[Parameter(Mandatory = $true)]
				[ValidateNotNullOrEmpty()]
				[string]$XslPath
			)
			$xslt = [System.Xml.Xsl.XslCompiledTransform]::new()
			$xslts = [System.Xml.Xsl.XsltSettings]::new($true,$true)
			$xsltr = [System.Xml.XmlUrlResolver]::new()
			#$xslts.EnableScript = $true
			#$xslts.EnableDocumentFunction = $true
			$xslt.Load($XslPath, $xslts, $xsltr)
			return $xslt
		}
		
		function Invoke-XslTransform {
			param (
				[Parameter(Mandatory = $true)]
				[ValidateNotNullOrEmpty()]
				[string]$XmlPath,
				 
				[Parameter(Mandatory = $true)]
				[ValidateNotNullOrEmpty()]
				[System.Xml.Xsl.XslCompiledTransform]$XslTransform,
				 
				[Parameter(Mandatory = $true)]
				[ValidateNotNullOrEmpty()]
				[string]$HtmlOutput,

				[Parameter(Mandatory = $false)]
				[hashtable]$Parameters
			)
			try {
				$args = [System.Xml.Xsl.XsltArgumentList]::new()
				if ($Parameters) {
					foreach ($kvp in $Parameters.GetEnumerator()) {
						$args.AddParam($kvp.Key,"",$kvp.Value)
					}
				}
				# create an XmlWriter with the output settings as defined in the style sheet
				$sw = [System.Xml.XmlWriter]::Create($HtmlOutput, $XslTransform.OutputSettings)
				try {
					$XslTransform.Transform($XmlPath, $args, $sw)
				}
				finally {
					$sw.Dispose()
				}
			}
			catch {
				Write-Host $_.Exception.InnerException -ForegroundColor Red
				throw $_.Exception
			}
		}
	}
	process {
		# process the input object(s) (filter $null out)
		$InputObject | where-object { $_ } | foreach-object {
			$files = $_
			if ($files -is [string]) {
				$files = get-item $files
			}
			if ($files -is [System.IO.DirectoryInfo]) {
				$files = get-childitem $files
			}
			foreach ($file in $files) {
				if ($file -isnot [System.IO.FileInfo]) {
				write-warning "   skipping '$file' (not a file)"
					continue
				}
				# filter non-ACN DDL modules out
				if ($file.Name -notmatch '(.ddl|.ddl.xml)$') {
				write-warning "   skipping '$file' (wrong extension)"
					continue
				}
				write-verbose " processing $file"

				$outfolder = if ($OutPath) { $(get-item $OutPath) } else { $file.DirectoryName }
				$outfilename = [System.IO.Path]::ChangeExtension($file.Name,$Extension)
				$outfile = [System.IO.Path]::Combine($outfolder,$outfilename)

				if ($UseMsXsl) {
					# test if the regular stylesheet is present, if so, use that
					$stylesheet = [System.IO.Path]::Combine($file.DirectoryName, "..", "xsl/acn.ddl.xsl")
					if (!(Test-Path $stylesheet)) {
						# use local backup stylesheet
						$stylesheet = [System.IO.Path]::Combine("$PSScriptRoot", "..", "xsl/acn.ddl.xsl")
					}
					# expand the xslt-params; not sure why, but providing the parameters as array
					# does work correctly in the msxsl call, joining as space separated string not :-()
					$params = @()
					foreach ($kvp in $xsltparams.GetEnumerator()) {
						$params += $kvp.key +'="'+$kvp.value+'"'
					}
					write-host "$($file.FullName) $stylesheet $params >$outfile"
					& msxsl $file.FullName $stylesheet $params >$outfile
				}
				else {
					if (($xslt -eq $null) -or ($xsltdir -ne $file.DirectoryName)) {
						$xsltdir = $file.DirectoryName
						# test if the file-specific regular stylesheet is present, if so, use that
						$stylesheet = [System.IO.Path]::Combine($file.DirectoryName, "..", "xsl/acn.ddl-to-html.xsl")
						if (!(Test-Path $stylesheet)) {
							$stylesheet = $DefaultSheet
						}
						$xslt = New-CompiledSheet $stylesheet
					}
					Invoke-XslTransform $file.FullName $xslt $outfile $xsltparams
				}
				get-item $outfile
			}
		}
	}
	end {
	}
}


Export-ModuleMember -Function *

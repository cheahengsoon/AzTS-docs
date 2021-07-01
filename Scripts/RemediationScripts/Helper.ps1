Set-StrictMode -Version Latest

class ResourceResolver
{
	[string[]] $ExcludeResourceNames=@();
	[PSObject] $ExcludedResources=@();
	[string[]] $ExcludeResourceGroupNames=@();
	
	# Indicates to fetch all resource groups
	ResourceResolver([string] $subscriptionId):
		Base($subscriptionId)
	{ }

	ResourceResolver([string] $excludeResourceName , [string] $excludeResourceGroupName)
	{
		if(-not [string]::IsNullOrEmpty($excludeResourceName))
		{
			$this.ExcludeResourceNames += $this.ConvertToStringArray($excludeResourceName)
			if ($this.ExcludeResourceNames.Count -eq 0)
			{
				throw "The parameter 'ExcludeResourceNames' does not contain any string."
			}	
		}

		if(-not [string]::IsNullOrEmpty($excludeResourceGroupName))
		{
			$this.ExcludeResourceGroupNames += $this.ConvertToStringArray($excludeResourceGroupName)
			if ($this.ExcludeResourceGroupNames.Count -eq 0)
			{
				throw "The parameter 'ExcludeResourceGroupNames' does not contain any string."
			}	
		}
	}

	[string[]] ConvertToStringArray([string] $stringArray)
	{
		$result = @();
		if(-not [string]::IsNullOrWhiteSpace($stringArray))
		{
			$result += $stringArray.Split(',', [StringSplitOptions]::RemoveEmptyEntries) | 
							Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
							ForEach-Object { $_.Trim() } |
							Select-Object -Unique;
		}
		return $result;
	}

	#method to filter SVT resources based on exclude flags
	hidden [PSObject] ApplyResourceFilter([PSobject] $Resources)
	{	
		$ResourceFilterMessage=[string]::Empty
		$ResourceGroupFilterMessage=[string]::Empty
		#First remove resource from the RGs specified in -ExcludeResourceGroupNames
		if(($this.ExcludeResourceGroupNames | Measure-Object).Count )
		{
			$matchingRGs= $this.ExcludeResourceGroupNames | Where-Object{$_ -in $Resources.ResourceGroupName}
			$nonExistingRGS = $this.ExcludeResourceGroupNames | Where-Object{$_ -notin $matchingRGs}
			if(($nonExistingRGS| Measure-Object).Count -gt 0)
			{
				#print the message saying these RGS provided in excludeRGS are not found
				Write-Host "`nWarning: Did not find following resource groups requested for exclusion:	`n" -ForegroundColor Yellow
				Write-Host $($nonExistingRGS -join ",")
				Write-Host `n
			}

			if(($matchingRGs| Measure-Object).Count -gt 0 )
			{
				# Check if given exclude resource name belongs from one of the given resource group name
				if(($this.ExcludeResourceNames | Measure-Object).Count)
				{
					$coincidingResources = $Resources | Where-Object {$_.ResourceName -in $this.ExcludeResourceNames -and $_.ResourceGroupName -in $matchingRGs}
					if(($coincidingResources| Measure-Object).Count -gt 0)
					{
						$this.ExcludeResourceNames = $this.ExcludeResourceNames | Where-Object {$_ -notin $coincidingResources.ResourceName}
						$this.ExcludedResources += $coincidingResources
						$matchingRGs = $matchingRGs | Where-Object { $_ -notin $coincidingResources.ResourceGroupName }
					}
				}

				# If no coinciding resource found the need to exclude given resource group name
				$this.ExcludedResources += $Resources| Where-Object{$_.ResourceGroupName -in $matchingRGs}
			}
		}
		
		#Remove resources specified in -ExcludeResourceNames
		if(($this.ExcludeResourceNames | Measure-Object).Count)
		{
			# check if resources specified in -xrns exist. If not then show a warning for those resources.
			$ResourcesToExclude =$this.ExcludeResourceNames
			$NonExistingResource = $this.ExcludeResourceNames | Where-Object { $_ -notin $Resources.ResourceName}
			if(($NonExistingResource | Measure-Object).Count -gt 0 )
			{
				$ResourcesToExclude = $this.ExcludeResourceNames | Where-Object{ $_ -notin $NonExistingResource }
				Write-Host "`nWarning: Did not find the following resources requested for exclusion: `n" -ForegroundColor Yellow
				Write-Host $(($NonExistingResource) -join ",")
				Write-Host `n
			}	
			
			$this.ExcludedResources += $Resources | Where-Object{$_.ResourceName -in $ResourcesToExclude}
		}
			
		$ResourcesToRemediate = $Resources | Where-Object {$_ -notin $this.ExcludedResources}
		return $ResourcesToRemediate
	}
}
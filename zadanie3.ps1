# Urbanowski Mieszko nr alb 3421

$reqModules = @(
    "Az.Accounts",
    "Az.Storage",
    "Az.Resources",
    "AzureAD"
)

$errorFlag = $false

foreach ($mod in $reqModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "Moduł $mod nie jest zainstalowany."
        Write-Host "Instalacja poleceniem: Install-Module -Name $mod"
        $errorFlag = $true
    }
}

if($errorFlag) {
    Exit
}

Import-Module Az.Accounts
Import-Module Az.Storage
Import-Module Az.Resources
Import-Module AzureAD

try {
    # https://stackoverflow.com/questions/61313906/is-it-possible-authenticate-both-connect-azaccount-and-connect-azuread-using-mfa
    Write-Host "Logowanie do konta AZ"
    Connect-AzAccount | Format-Table
    Write-Host "Logowanie do konta AD (auto)"
    $context=Get-AzContext
    Connect-AzureAD -TenantId $context.Tenant.TenantId -AccountId $context.Account.Id | Format-Table
} catch { 
    Show-Except -obj $_
    exit
}

function Show-Except {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[PSObject]] $obj
        )
    
    Write-Host
    Write-Host "Wystąpił błąd"
    Write-Host "=================================================="
    Write-Host "$obj"
    Write-Host "=================================================="
    Write-Host
}

function Get-User-Choice {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MenuName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Options
    )
    return($Options[(Show-Menu -MenuName $MenuName -Options $Options)])
}

function Get-User-Input {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrompt,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$defaultValue
    )
            
    if (!($val = Read-Host "$UserPrompt [$defaultValue]")) { $val = $defaultValue }
    return $val
}

function Show-Menu {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MenuName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Options
    )

    Clear-Host
    Write-Host "$MenuName ================"

    if($Options.Count -eq 0) {
        Write-Host "Brak pozycji do wyświetlenia"
    } else {

    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host ("{0,3}. {1}" -f ($i + 1), $Options[$i])
    }
    }
    Write-Host ("{0,3}. Wyjście z programu lub przerwanie aktualnej operacji" -f "Q")
    Write-Host

    while ($true) {
        $choice =  Read-Host "Wybór "
        try {
        if(($choice.Equals("q")) -Or ($choice.Equals("Q"))) {
            break subloop
        }

        $choice = [int]$choice

        if ($choice -ge 1 -and $choice -le $Options.Count) {
            return ($choice - 1)
        }
        Write-Host("Błędny wybór {0}. Wybierz wartość z zakresu 1-{1} lub 'q' aby przerwać" -f $choice, $Options.Count)
    } catch {
        Show-Except -obj $_
    }
    }
}

#############################################
#
# Główna pętla programu
#
#############################################

$menu = @(
    "Informacje o mojej subskrypcji",
    "Lista dostępnych kont storage",
    "Lista dostępnych regionów (Europa)",
    "Stworzenie nowego konta storage (Europa)",
    "Stworzenie File Share w istniejącym storage account z wskazaniem na tear i qouta",
    "Lista grup dostępnych w azure AD",
    "Dopisanie wybranej grupie uprawnień 'Storage Account Contributor' do wybranej grupy zasobów",
    "Kasowanie wskazanego storage account"
)

do
 {
    
    $choice = Show-Menu -MenuName "Menu programu" -Options $menu
    Clear-Host
    :subloop switch ($choice)
    {
    '0' {
        # "Informacje o mojej subskrypcji",
        try {
             Get-AzSubscription | Format-Table
    } catch { 
        Show-Except -obj $_
    }
    } '1' {
        # "Lista dostępnych kont storage",
        try {
             Get-AzStorageAccount | Select-Object StorageAccountName |  Format-Table
    } catch { 
        Show-Except -obj $_
    }
    } '2' {
        # "Lista dostępnych regionów",
        try {
             Get-AzLocation  | Select-Object Location, DisplayName |  Format-Table
    } catch { 
        Show-Except -obj $_
    }
    } '3' {
        # "Stworzenie nowego konta storage",
        try {
            Write-Host("Odczytuję dostępne lokalizacje")
            $locations = Get-AzLocation | Where-Object GeographyGroup -eq "Europe" | Select-Object -ExpandProperty Location 
            
            Write-Host("Odczytuję dostępne ResourceGroup")
            $resourceGroups = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName
            
            $location = Get-User-Choice -MenuName "Wybierz lokalizację" -Options $locations
            $resourceGroup = Get-User-Choice -MenuName "Wybierz Resource Group" -Options $resourceGroups
            $name = Get-User-Input -UserPrompt "Podaj nazwę dla Storage Account" -defaultValue $("umstorageacct$(Get-Random)")

            New-AzStorageAccount -ResourceGroupName $resourceGroup -Name $name -Location $location -SkuName Standard_LRS -Kind StorageV2 -AllowBlobPublicAccess $true | Format-Table
        } catch { 
            Show-Except -obj $_
        }
        
    } '4' {
        # "Stworzenie File Share w istniejącym storage account z wskazaniem na tear i qouta",
        $tierOptions = @(
            "TransactionOptimized",
            "Cool",
            "Hot",
            "Premium"
        )

        try {
            Write-Host("Odczytuję Storage Accounts")
            $storageAccounts = Get-AzStorageAccount | Select-Object -ExpandProperty StorageAccountName 
            
            Write-Host("Odczytuję dostępne ResourceGroup")
            $resourceGroups = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName

            $resourceGroup = Get-User-Choice -MenuName "Wybierz Resource Group" -Options $resourceGroups
            $storageAccount = Get-User-Choice -MenuName "Wybierz Storage Account" -Options $storageAccounts
            $tier = Get-User-Choice -MenuName "Wybierz Access Tier" -Options $tierOptions
            $quota = Get-User-Input -UserPrompt "Podaj quotę (w GiB) dla File Share" -defaultValue "1024"
            $name = Get-User-Input -UserPrompt "Podaj nazwę dla File Share" -defaultValue $("umfileshare$(Get-Random)")
            # Utworzenie nowego File Share z określonym tierem i quotą
            New-AzRmStorageShare -ResourceGroupName $resourceGroup -StorageAccountName $storageAccount -Name $name -AccessTier $tier -QuotaGiB $quota | Format-Table
        } catch { 
            Show-Except -obj $_
        }

    } '5' {
        # "Lista grup dostępnych w azure AD",
        try {
            Get-AzureADGroup | Select-Object DisplayName, Description | Format-Table
        } catch { 
            Show-Except -obj $_
        }
    } '6' {
        # "Dopisanie wybranej grupie uprawnień 'Storage Account Contributor' do wybranej grupy zasobów",
        try {
            $roleName = "Storage Account Contributor"

            Write-Host("Odczytuję grupy AD")
            $adGroups = Get-AzureADGroup | Select-Object -ExpandProperty DisplayName

            Write-Host("Odczytuję dostępne ResourceGroup")
            $resourceGroups = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName

            $adGroupName = Get-User-Choice -MenuName "Wybierz grupę AD" -Options $adGroups
            
            Write-Host("Odczytuję id grupy")
            $adGroup = Get-AzureADGroup | Where-Object DisplayName -eq $adGroupName

            $resourceGroup = Get-User-Choice -MenuName "Wybierz Resource Group" -Options $resourceGroups

            New-AzRoleAssignment -ObjectId $adGroup.ObjectId -RoleDefinitionName $roleName -ResourceGroupName $resourceGroup | Format-Table 
        } catch { 
            Show-Except -obj $_
        }

    } '7' {
        # "Kasowanie wskazanego storage account"
        try {
            Write-Host("Odczytuję Storage Accounts")
            $storageAccounts = Get-AzStorageAccount | Select-Object -ExpandProperty StorageAccountName 
            
            $storageAccount = Get-User-Choice -MenuName "Wybierz Storage Account do usunięcia" -Options $storageAccounts

            Write-Host("Odczytuję ResourceGroup dla $storageAccount")
            $resourceGroup = $(Get-AzStorageAccount | Where-Object StorageAccountName -eq $storageAccount).ResourceGroupName
                        
            Remove-AzStorageAccount -Name $storageAccount -ResourceGroupName $resourceGroup
        } catch { 
            Show-Except -obj $_
        }

    } 

    }
    Pause
    
 }
 until ($choice -eq 'q')

try {
Disconnect-AzureAD
Disconnect-AzAccount
} catch {
    Show-Except -obj $_
}
Exit


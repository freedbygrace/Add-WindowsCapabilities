Get the ReleaseID of Windows 10 that you intend to deploy. The script will attempt to automatically detect which version from the image path, but the folder structure must be in place to support it.

Example: 1909

Create a folder structure like the following

Example:

1909
1909\X86
1909\X64

Place the appropriate Feature On Demand cabinet files into the respective architecture of the image you are deploying.

1909\X86\Source\Place 32-Bit Feature On Demand Cabinet Files Here
1909\X64\Source\Place 64-Bit Feature On Demand Cabinet Files Here

The script will attempt to locate the cabs automatically and use them as the installation source for enabling the specified capabilities after exporting them.

Types of Features on Demand (https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-v2--capabilities)
Starting with Windows 10, version 1809 and Windows Server 2019, Windows has two different types of Features on Demand:
FODs without satellite packages: FODs with all language resources packaged into the same package. These FODs are distributed as a single .cab file.
They can be added using either DISM /Add-Capability or /Add-Package.
FODs with satellite packages: Language-neutral FODs that have language and/or architecture resources in separate packages (satellites). When you install this type of FOD, only the packages that apply to the Windows image are installed, which reduces disk footprint. These FODs are distributed as a set of several .cab files, but are installed by specifying a single /capabilityname. These are new for Windows 10, version 1809.
They can only be added using DISM /Add-Capability (and not /Add-Package).
FODs with satellites require a well-formed FOD repository. This can either be the full FOD repository on the ISO, or a custom repository created with DISM /export-source. They cannot be added by pointing to a directory with a handful of FOD files hand-copied from the repository, because DISM requires additional metadata to make the right connections.

Note: As of the most recent builds of Windows 10, you can find the Feature On Demand cabinet files for the .NET Framework directly inside the ISO inside the ".\Sources\SXS" folder. Otherwise, you will have to download the Feature On Demand ISOs for your respective version of Windows 10.

Note: Sometimes Microsoft will not release a newer version of the Features On Demand iso file(s), but they will place a notice saying that you could perhaps use the most recently released version. This took place with Windows 10 1903 and 1909. You were able to use the same cabinet files for both releases.

##################################
No access to WSUS here. I didn’t want to mount the ISO or copy the whole 4.6GB down to the clients to install this, so I experimented to see what the bare minimum I needed for just the Active Directory Users and Computers for Australian English was.

First, I copied only:

Microsoft-Windows-ActiveDirectory-DS-LDS-Tools-FoD-Package~31bf3856ad364e35~amd64~~.cab
Microsoft-Windows-ActiveDirectory-DS-LDS-Tools-FoD-Package~31bf3856ad364e35~amd64~en-US~.cab

When I did this, I was getting a “The source files could not be found” error. It turns out that you also need the metadata folder and the files within. I did not need FoDMetadata_Client.cab.

41 files at 6MB total.
###################################
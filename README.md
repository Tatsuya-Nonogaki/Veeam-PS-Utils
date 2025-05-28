# [Veeam-PS-Utils](https://github.com/Tatsuya-Nonogaki/Veeam-PS-Utils)

Welcome to the **Veeam PowerShell Utilities** repository! This collection of PowerShell scripts and supplementary tools is designed to simplify and enhance the management of Veeam Backup and Replication jobs.

---

## Scripts Included

### 1. `JobList.ps1`

#### Overview
The `JobList.ps1` script outputs a comprehensive list of Veeam Backup & Replication jobs to a CSV file. It supports classic job types (`backup`, `replica`) as well as `SureBackup` jobs, making it easy for backup administrators to analyze, audit, or document Veeam job configurations and operational status.

#### Key Features
- Exports detailed job information in CSV format for easy review and further analysis.
- Supports filtering by job type: `backup`, `replica`, or `surebackup`.
- Dynamically adapts output fields and logic depending on the selected job type.
- Optionally includes current job status and last session statistics with the `-Stat` parameter.
- Output file location is flexible and defaults intelligently based on job type.
- Designed to be robust and informative, with clear messages when no jobs match the specified criteria.

#### Parameters

- **`-Type` (Alias: `-t`)** (Mandatory):  
  Specifies the type of job to list. Must be `backup`, `replica`, or `surebackup`.

- **`-Log` (Alias: `-l`)**:  
  Specifies the CSV output file path. If not provided, defaults to `joblist-{type}.csv` in the script's directory.  
  If no path separator (`\`) is present, the file is created in the script directory.

- **`-Stat` (Alias: `-s`)**:  
  When used, adds status/session columns to the CSV, such as `IsRunning`, `LastResult`, `SessionStart`, `SessionEnd`, and `Duration`.

#### Output Fields

The CSV output includes the following columns, which vary according to job type and the use of `-Stat`:

| Field              | Description                                                                                                 | Applies to         |
|--------------------|-------------------------------------------------------------------------------------------------------------|--------------------|
| `Name`             | Job name                                                                                                    | All                |
| `JobType`          | Backup, Replica, or SureBackup                                                                              | All                |
| `Description`      | Description field of the job                                                                                | All                |
| `Sources`          | Source objects (for SureBackup, replaced by `LinkedJob`)                                                    | Backup, Replica    |
| `LinkedJob`        | Linked job(s) for SureBackup jobs                                                                           | SureBackup         |
| `TargetRepository` | Target repository for backup jobs                                                                           | Backup             |
| `TargetCluster`    | Target hypervisor cluster for the replica VM(s)                                                             | Replica            |
| `TargetFolder`     | Target virtual machine folder for the replica VM(s)                                                         | Replica            |
| `TargetDatastore`  | Target storage/datastore for the replica VM(s)                                                              | Replica            |
| `RestorePoints`    | Number of restore points to keep (with unit: days/points)                                                   | Backup, Replica    |
| `IsScheduleEnabled`| `FALSE` indicates the job will not run automatically because it is disabled in the Jobs list pane.           | All                |
| `RunAutomatically` | `FALSE` indicates the job will not run automatically because the “Run the job automatically” checkbox is unchecked on the Schedule page of the job configuration. | All                |
| `DailyStartTime`   | Value present only if the “Daily” selector is checked in the Schedule page of the job configuration.         | All                |
| `MonthlyStartTime` | Value present only if the “Monthly” selector is checked in the Schedule page of the job configuration.       | All                |
| `Periodically`     | Value present only if the “Periodically” selector is checked in the Schedule page of the job configuration.  | Backup, Replica    |
| `HourlyOffset`     | Time offset configured in the "Start time within an hour" field in the advanced option of the Periodic. Present only if “Periodically” is selected. | Backup, Replica    |
| `AfterJob`         | Name of the job that triggers this job when it completes (“After the job” scheduling). Value present only if the selector is checked in the Schedule page. | All |
| `IsRunning`        | Indicates whether the job is running at the time of report                                                  | All (`-Stat` only) |
| `LastResult`       | Result of the last job session (Success, Warning, Failed, None)                                             | All (`-Stat` only) |
| `SessionStart`     | Start time of the last job session                                                                          | All (`-Stat` only) |
| `SessionEnd`       | End time of the last job session                                                                            | All (`-Stat` only) |
| `Duration`         | Duration of the last job session                                                                            | All (`-Stat` only) |

#### Usage Examples

```powershell
# Output all backup jobs to CSV including job status/session columns (relative path)
.\JobList.ps1 -Type backup -Log .\backup_jobs.csv -Stat

# Output all replica jobs to the default CSV file (no status columns)
.\JobList.ps1 -Type replica

# Output all SureBackup jobs to a custom path, with status columns
.\JobList.ps1 -Type surebackup -Log "C:\Reports\surebackup_jobs.csv" -Stat
```

---

### 2. `JobStatus.ps1`

#### Overview
The `JobStatus.ps1` script retrieves the last result of a specified Veeam Backup and Replication job. It supports logging and provides exit codes for easy integration with monitoring systems.

#### Key Features
- Retrieves the last job result, including success, warning, or failure status.
- Records output to a log file unless prohibited.
- Returns exit codes for easy integration with scripts or monitoring tools.

#### Parameters
- **`-JobName` (Alias: `-j`)** (Mandatory):
  Specifies the name of the job to check.

- **`-Log` (Alias: `-l`)**:
  Appends logs to the specified file. Defaults to `jobstatus.log` in the script's directory if not provided.

- **`-NoLog`**:
  Disables logging, even if a log file is specified.

- **`-Quiet` (Alias: `-q`)**:
  Suppresses console output. Results can still be accessed via exit codes or the log file.

#### Exit Codes
- `0`: Job finished with "Success" status.
- `1`: Job finished with "Failed" status.
- `2`: Job finished with "Warning" status.
- `4`: No job record is available or pending ("None" status).
- `8`: Unknown status.
- Other: Errors such as non-existent job name or syntax issues.

#### Usage Example
```powershell
# Check the status of a backup job and log the result
.\JobStatus.ps1 -JobName "DailyBackup" -Log backup_status.log
```

---

### 3. `VBRStatusWrapper.bat`

#### Overview
The `VBRStatusWrapper.bat` script is a wrapper for `JobStatus.ps1` to facilitate exit code retrieval in batch environments. It ensures seamless integration with batch files and other tools.

#### Key Features
- Executes `JobStatus.ps1` and returns its exit code.
- Simplifies integration with batch scripts and legacy systems.

#### Usage Example
```batch
:: Check the status of a backup job
VBRStatusWrapper.bat DailyBackup
```

---

### 4. `RunVBRJob.ps1`

#### Overview
The `RunVBRJob.ps1` script starts a specified Veeam Backup and Replication job and retrieves its result. It uses a configuration file (`settings.ps1`) for global settings. It is also designed to work in conjunction with external monitoring systems and job schedulers, making it suitable for automated workflows.

#### Key Features
- Starts a VBR job and retrieves its result.
- Logs job execution summary and result status to a file.
- Supports passing additional options to the `Start-VBRJob` cmdlet via the `-VBRJobOpt` parameter.
- Can use different global configuration file for individual or groups of execution.
- Integrates seamlessly with external monitoring systems and job schedulers for automated task management.

#### Parameters
- **`-JobName` (Alias: `-j`)** (Mandatory):
  Specifies the name of the job to start.

- **`-Config` (Alias: `-c`)**:
  Specifies an alternative configuration file. Defaults to `settings.ps1` in the script's directory.

- **`-VBRJobOpt` (Alias: `-o`)**:
  Passes additional options to the `Start-VBRJob` cmdlet. Example: `-VBRJobOpt "-FullBackup -RetryBackup"`.

- **`-Log` (Alias: `-l`)**:
  Appends logs to the specified file. Overrides the `$Set_Log` parameter in `settings.ps1`.

- **`-NoExec` (Alias: `-n`)**:
  Returns the result of the last session without executing the job.

- **`-Quiet` (Alias: `-q`)**:
  Suppresses console output. Results can still be accessed via logs or exit codes.

#### Configuration (`settings.ps1`)
The `settings.ps1` file is used for global configurations. It includes settings such as the default log file:

```powershell
# File to append logs to. Comment it out or set null if no logging is required.
$Set_Log = 'vbrjob.log'
```

#### Exit Codes
- `0`: Job finished with "Success" status.
- `1`: Job finished with "Failed" status.
- `2`: Job finished with "Warning" status.
- `4`: No job record is available or pending ("None" status).
- `8`: Unknown status.
- Other: Errors such as non-existent job name or syntax issues.

#### Usage Example
```powershell
# Run a backup job with custom options
.\RunVBRJob.ps1 -JobName "WeeklyBackup" -VBRJobOpt "-FullBackup" -Log job_run.log
```

---

### 5. `VBRJobWrapper.bat`

#### Overview
The `VBRJobWrapper.bat` script is a wrapper for `RunVBRJob.ps1` to facilitate execution in batch environments. It ensures that exit codes from `RunVBRJob.ps1` are correctly captured and returned to the calling environment, making it ideal for integration with external monitoring systems or job schedulers.

#### Key Features
- Executes `RunVBRJob.ps1` and passes all arguments to it.
- Correctly captures and propagates the exit code from `RunVBRJob.ps1`.
- Simplifies the usage of `RunVBRJob.ps1` in batch scripts or legacy systems.
- Designed for use in automated workflows with monitoring systems and schedulers.

#### Usage Example
```batch
:: Run a backup job with custom options
VBRJobWrapper.bat WeeklyBackup -o "-FullBackup -RetryBackup"
```

---

### 6. `DisableVBRJob.ps1`

#### Overview

The `DisableVBRJob.ps1` script enables, disables, or checks the status of Veeam Backup & Replication jobs in a safe, flexible, and auditable manner. It is designed for both broad and highly specific job selection, offering robust safeguards against accidental changes. **As of v0.3.x, the `-Type` parameter is mandatory and central to all job selection logic.**

#### The Role of `-Type` (and the meaning of "classic")

**You MUST always specify `-Type`** to select which class of jobs are targeted for action.
- `"classic"` is a convenient umbrella invented for this script—it means “all operational jobs except SureBackup.”
- `"classic"` includes: backup, replica, backup copy (internally called `SimpleBackupCopyPolicy`), and other Veeam job types, but _excludes_ SureBackup jobs.
- `"surebackup"` exclusively targets SureBackup jobs.
- You may also specify a precise type (e.g., `"backup"`, `"replica"`, `"backupcopy"`).

This design ensures that **only jobs matching the specified `-Type` are ever targeted, regardless of how you supply names or lists**. Thus, even if your list contains jobs of multiple types, or you use a broad selection, only those matching your chosen `-Type` will be acted upon.
This double-filtering logic provides strong safeguards and ensures that actions are always intentional.

#### Job Selection Logic

- **Filtering always starts with `-Type`.**
  Only jobs of the specified type/class are considered for further selection.
- **You may further narrow the scope** using:
  - `-JobName` — one specific job (must still match the type).
  - `-ListFile` — a text file with job names (one per line); only jobs of the specified type _and_ found in the list will be targeted.
- This means you can use a single list file containing mixed job types, and safely operate only on the ones matching your `-Type` filter.
- Alternatively, you may prepare separate list files for each type. If you accidentally use the wrong list with the wrong `-Type`, the script will safely filter out unmatched jobs, adding another safety net.

#### Parameters

| Parameter   | Alias | Required | Description |
|-------------|-------|----------|-------------|
| `-Type`     | `-t`  | Yes      | Job type to target: `"classic"`, `"surebackup"`, or a specific classic job type (`"backup"`, `"replica"`, `"backupcopy"`).<br>- `"classic"` = all non-SureBackup jobs.<br>- `"surebackup"` = only SureBackup jobs.<br>- Specific types = only jobs of that type. |
| `-JobName`  | `-n`  | No*      | Name of a single job to target. Cannot be combined with `-ListFile`. The job must also match `-Type`. |
| `-ListFile` | `-f`  | No*      | Path to file containing job names (one per line). Use `"default"` to use `joblist.txt` in the script directory. Cannot be used with `-JobName`. Only jobs matching both the list and type will be targeted. |
| `-Disable`  | `-d`  | No       | Disable the selected jobs. Mutually exclusive with `-Enable` and `-Status`. **Default action if none is specified.** |
| `-Enable`   | `-e`  | No       | Enable the selected jobs. Mutually exclusive with `-Disable` and `-Status`. |
| `-Status`   | `-s`  | No       | Show the enable/disable status of the selected jobs. Mutually exclusive with `-Disable` and `-Enable`. |

> \* At least one of `-Type`, `-JobName`, or `-ListFile` **must** be used to select jobs, but `-Type` is always required.

#### Behavior Notes

- If a job’s **“Run automatically”** option is not enabled in its schedule, enabling or disabling has no effect (the job is skipped with a warning).  
  _Exception: This skip logic does **not** apply to Backup Copy jobs (`backupcopy`, Veeam type `SimpleBackupCopyPolicy`), as these jobs operate on a “backup window” basis (either “always” or a specific time window) and do not have a “Run automatically” toggle or standard schedule option._
- The script always prompts for confirmation before enabling or disabling jobs, listing all targeted jobs clearly.
- Color-coded output and explicit messages help distinguish actions, skips, and errors.
- Filtering is always an AND operation: e.g., `-Type classic -ListFile mylist.txt` means “all classic jobs **and** also present in `mylist.txt`.”
- Using `-Type surebackup` will **never** match classic jobs, even if their names appear in a list file. Neither do SureBackup jobs if `-Type classic` is used.

#### Usage Examples

```powershell
# Disable all backup jobs listed in a file (only classic backup jobs in the list will be targeted)
.\DisableVBRJob.ps1 -Type backup -ListFile jobs_to_disable.txt -Disable

# Enable a single replica job by name
.\DisableVBRJob.ps1 -Type replica -JobName "WeeklyReplication" -Enable

# Show status of all SureBackup jobs
.\DisableVBRJob.ps1 -Type surebackup -Status

# Disable all classic (non-SureBackup) jobs in the default list file
.\DisableVBRJob.ps1 -Type classic -ListFile default
```

#### Best Practices and Safety Tips

- You may use a single, master list file for all job names—let `-Type` do the safe filtering for you!
- If you prefer, you can use separate list files per job type; even then, `-Type` acts as a failsafe against accidental cross-type operations.
- **Safety workflow:** Before making changes, run the script with `-Status` and your intended selection parameters to preview the jobs that would be affected. This lets you confirm that your `-Type` and list file selections are correct—especially valuable in production!
- Always review the confirmation prompt and the displayed job list before approving changes—this is your last line of defense for production safety.

---

## Contribution
Feel free to raise issues or contribute to this project by creating pull requests. Contributions are welcome to enhance the utility of these scripts!

---

## License
This repository is licensed under the [MIT License](LICENSE).

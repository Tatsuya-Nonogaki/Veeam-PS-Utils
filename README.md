# [Veeam PowerShell Utilities](https://github.com/Tatsuya-Nonogaki/Veeam-PS-Utils)

Welcome to the **Veeam PowerShell Utilities** repository! This collection of PowerShell scripts and supplementary tools is designed to simplify and enhance the management of Veeam Backup and Replication jobs.

---

## Scripts Included

### 1. `JobList.ps1`

#### Overview
The `JobList.ps1` script outputs a list of Veeam Backup and Replication jobs to a CSV file. It provides major properties of each job, enabling backup administrators to easily analyze and manage their configurations.

#### Key Features
- Outputs job information to a CSV file.
- Supports filtering jobs by type (`backup` or `replica`).
- Outputs fields dynamically based on the job type.
- Includes additional job status information when the `-Stat` parameter is specified.

#### Parameters
- **`-Type` (Alias: `-t`)** (Mandatory):
  Specifies the type of job to list. Must be either `backup` or `replica` for the time being.

- **`-Log` (Alias: `-l`)**:
  Specifies the output file path. Defaults to `joblist-{Type}.csv` in the script's directory if not provided.

- **`-Stat` (Alias: `-s`)**:
  Includes additional status-related columns such as `IsRunning`, `LastResult`, `SessionStart`, `SessionEnd`, and `Duration` in the output.

#### Output Fields
The CSV output consists of the following fields:

| Field              | Description                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| `Name`             | Job Name.                                                                   |
| `JobType`          | Type of job (e.g., Backup, Replica).                                        |
| `Description`      | Description of the job.                                                     |
| `Sources`          | Source objects of the backup/replication job.                               |
| `TargetRepository` | (Backup only) Target repository for backups.                                |
| `TargetCluster`    | (Replica only) Target cluster for replication.                              |
| `TargetFolder`     | (Replica only) Target folder for replication.                               |
| `TargetDatastore`  | (Replica only) Target datastore for replication.                            |
| `RestorePoints`    | Number of restore points to keep.                                           |
| `IsScheduleEnabled`| Indicates if the job is enabled.                                            |
| `RunAutomatically` | Indicates if the job runs automatically based on its configuration.         |
| `DailyStartTime`   | Configured daily start time (if applicable).                                |
| `Periodically`     | Interval for periodic execution (if applicable).                            |
| `HourlyOffset`     | Time offset within an hour for periodic schedules (if applicable).          |
| `IsRunning`        | (Optional, with `-Stat`) Indicates if the job is running.                   |
| `LastResult`       | (Optional, with `-Stat`) Result of the last job session.                    |
| `SessionStart`     | (Optional, with `-Stat`) Start timestamp of the last session.               |
| `SessionEnd`       | (Optional, with `-Stat`) End timestamp of the last session.                 |
| `Duration`         | (Optional, with `-Stat`) Duration of the last job.                          |

#### Usage Example
```powershell
# Output backup jobs to a CSV file with additional status information
.\JobList.ps1 -Type backup -Log backup_jobs.csv -Stat
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
The `DisableVBRJob.ps1` script enables, disables, or checks the status of Veeam Backup & Replication jobs. It supports targeting jobs by name, type, or a list file, and provides pre-checks for job existence and scheduling settings. This script is useful for maintenance, automation, or scheduled operational tasks.  
**As of v0.2.0, the script is tested for both classic jobs (e.g., backup, replica) and SureBackup jobs (type: `surebackup`).**

#### Key Features
- Enables, disables, or checks the status of one or more Veeam jobs.
- Target jobs by name (`-JobName`), type (`-Type`), or a list file (`-ListFile`).
- Safeguards against conflicting parameters and missing or non-existent jobs.
- Skips jobs not configured for automatic scheduling and informs the operator.
- Provides clear, color-coded status and operation messages.
- Combines multiple selection criteria with AND logic.

#### Parameters
- **`-ListFile` (Alias: `-f`)**: Reads a list of job names from a file. Use `'default'` to refer to the script's default list file. Cannot be combined with `-JobName`.
- **`-JobName` (Alias: `-n`)**: Specifies a single job name directly. Cannot be combined with `-ListFile`.
- **`-Type` (Alias: `-t`)**: Filters jobs by type (`backup`, `replica`, or `surebackup`).
- **`-Disable` (Alias: `-d`)**: Disables the target jobs. Mutually exclusive with `-Enable` and `-Status`. Default if no action is specified.
- **`-Enable` (Alias: `-e`)**: Enables the target jobs. Mutually exclusive with `-Disable` and `-Status`.
- **`-Status` (Alias: `-s`)**: Shows the enable/disable status of the target jobs. Mutually exclusive with `-Enable` and `-Disable`.

#### Behavior Notes
- If a job's "Run automatically" option is not checked in its Schedule settings, enabling/disabling has no effect and the script will skip the job with a clear informational message.
- Jobs can be targeted with multiple filters, but at least one of `-ListFile`, `-JobName`, or `-Type` must be used.
- The script handles all necessary checks before performing any job modifications.

#### Usage Examples
```powershell
# Disable all backup jobs listed in a file
.\DisableVBRJob.ps1 -ListFile jobs_to_disable.txt -Type backup -Disable

# Enable a single job by name
.\DisableVBRJob.ps1 -JobName "WeeklyReplication" -Enable

# Show the status of all SureBackup jobs
.\DisableVBRJob.ps1 -Type surebackup -Status
```

---

## Contribution
Feel free to raise issues or contribute to this project by creating pull requests. Contributions are welcome to enhance the utility of these scripts!

---

## License
This repository is licensed under the [MIT License](LICENSE).

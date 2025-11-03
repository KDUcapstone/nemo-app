$ErrorActionPreference = 'Stop'

git fetch --all --prune | Out-Null

$BASE = 'origin/main'
$STAMP = Get-Date -Format 'yyyyMMdd-HHmmss'
$BACKUP = "backup/split-$STAMP"
$CURRENT = (git rev-parse --abbrev-ref HEAD).Trim()

# 변경사항이 있으면 stash로 보관 후 그 커밋을 소스로 사용
$hadLocalChanges = -not [string]::IsNullOrWhiteSpace((git status --porcelain))
if ($hadLocalChanges) {
    git stash push -u -m "split-$STAMP" | Out-Null
    $SOURCE = 'stash@{0}'
} else {
    $SOURCE = $BACKUP
}

git branch $BACKUP | Out-Null

$diff = git diff --name-status "$BASE..HEAD"

$entries = @()
foreach ($line in $diff) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "`t"
    if ($parts.Count -lt 2) { continue }
    $status = $parts[0]
    if ($status -like 'R*') {
        $old = $parts[1]
        $new = $parts[2]
        $entries += [pscustomobject]@{ status = 'D'; path = $old }
        $entries += [pscustomobject]@{ status = 'A'; path = $new }
    } else {
        $path = $parts[1]
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $entries += [pscustomobject]@{ status = $status; path = $path }
        }
    }
}

$groups = @(
    [pscustomobject]@{ branch='feature/mypage';      scope='mypage';      regex='mypage|my[_-]?page|profile|(?<!data/)me\b' },
    [pscustomobject]@{ branch='feature/share-album'; scope='share-album'; regex='share.*album|album.*share|share[-_]?album|shared[_-]?album' },
    [pscustomobject]@{ branch='feature/album';       scope='album';       regex='(?<!share[-_])album' },
    [pscustomobject]@{ branch='feature/friend';      scope='friend';      regex='friend|friends' },
    [pscustomobject]@{ branch='feature/photo';       scope='photo';       regex='photo|image|picture|\bpic\b' },
    [pscustomobject]@{ branch='feature/home';        scope='home';        regex='home|main[_-]?shell|\bmain\b' }
)

$used = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($g in $groups) {
    $matched = @()
    foreach ($e in $entries) {
        if ($used.Contains($e.path)) { continue }
        if ($e.path -match $g.regex) { $matched += $e }
    }
    if ($matched.Count -eq 0) { continue }

    git checkout -B $($g.branch) $BASE | Out-Null

    $adds = @()
    $dels = @()
    foreach ($m in $matched) {
        if ($m.status -eq 'D') { $dels += $m.path } else { $adds += $m.path }
    }

    if ($adds.Count -gt 0) { git restore --source=$SOURCE --staged --worktree -- $adds }
    if ($dels.Count -gt 0) { git rm -- $dels }

    $staged = (git diff --cached --name-only)
    if (-not [string]::IsNullOrWhiteSpace($staged)) {
        git commit -m "feat($($g.scope)): migrate pre-split changes" | Out-Null
    } else {
        Write-Host "No staged changes for $($g.branch), skipping commit"
    }

    foreach ($m in $matched) { $null = $used.Add($m.path) }
}

git checkout $CURRENT | Out-Null

if ($hadLocalChanges) {
    # 원래 작업 상태 복구
    git stash pop | Out-Null
}

Write-Host "Backup: $BACKUP"
Write-Host "Current: $CURRENT"
Write-Host "Split complete."



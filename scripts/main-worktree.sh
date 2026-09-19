#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
expected_branch=main
branch_pattern='^Anti2077/task-([0-9]{3})-[a-z0-9][a-z0-9-]*$'

fail() {
    print -u2 -- "main-worktree: $*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  ./scripts/main-worktree.sh check [--clean]
  ./scripts/main-worktree.sh merge <feature-branch>

Commands:
  check           Verify the real primary checkout is on symbolic branch main.
  check --clean   Also require a completely clean working tree.
  merge           Run guarded preflight checks, then merge with --no-ff.
EOF
}

assert_primary_checkout() {
    local require_clean=${1:-false}
    local git_root current_branch marker marker_path dirty_state
    local -a operation_markers

    [[ -d "${project_root}/.git" ]] || fail \
        "${project_root} is not the primary checkout (.git is not a directory). Run this command from the primary worktree."

    cd "${project_root}"

    git_root=$(git rev-parse --show-toplevel 2>/dev/null) || fail \
        "${project_root} is not a Git working tree."
    [[ "${git_root:A}" == "${project_root:A}" ]] || fail \
        "repository root mismatch: expected ${project_root}, found ${git_root}."

    current_branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || fail \
        "the primary checkout has a detached HEAD; switch it to ${expected_branch}."
    [[ "${current_branch}" == "${expected_branch}" ]] || fail \
        "the primary checkout must be on ${expected_branch}; found ${current_branch}."

    operation_markers=(
        MERGE_HEAD
        CHERRY_PICK_HEAD
        REVERT_HEAD
        rebase-merge
        rebase-apply
        sequencer
    )
    for marker in "${operation_markers[@]}"; do
        marker_path=$(git rev-parse --git-path "${marker}")
        [[ ! -e "${marker_path}" ]] || fail \
            "Git operation state ${marker} is present. Finish or abort it before primary-worktree integration."
    done

    if [[ "${require_clean}" == true ]]; then
        dirty_state=$(git status --porcelain=v1 --untracked-files=all)
        if [[ -n "${dirty_state}" ]]; then
            print -u2 -- "${dirty_state}"
            fail "the primary working tree must be completely clean before integration."
        fi
    fi
}

feature_worktree_for_branch() {
    local feature_branch=$1
    local line current_worktree=''
    local -a matches

    matches=()
    while IFS= read -r line; do
        if [[ "${line}" == worktree\ * ]]; then
            current_worktree=${line#worktree }
        elif [[ "${line}" == "branch refs/heads/${feature_branch}" ]]; then
            matches+=("${current_worktree}")
        fi
    done < <(git worktree list --porcelain)

    (( ${#matches[@]} <= 1 )) || fail \
        "feature branch ${feature_branch} is associated with multiple worktrees. Resolve the Git metadata before integration."

    if (( ${#matches[@]} == 1 )); then
        print -r -- "${matches[1]}"
    fi
}

validate_feature_branch() {
    local feature_branch=$1
    local task_number task_prefix task_path task_content task_status
    local feature_worktree feature_dirty candidate
    local -a task_paths

    [[ "${feature_branch}" != "${expected_branch}" ]] || fail \
        "${expected_branch} is the integration target, not a feature branch."
    git check-ref-format --branch "${feature_branch}" >/dev/null 2>&1 || fail \
        "${feature_branch} is not a valid branch name."
    git show-ref --verify --quiet "refs/heads/${feature_branch}" || fail \
        "local feature branch ${feature_branch} does not exist."

    [[ "${feature_branch}" =~ ${branch_pattern} ]] || fail \
        "feature branches must match Anti2077/task-NNN-short-name; found ${feature_branch}."
    task_number=${match[1]}
    task_prefix="TASK-${task_number}"

    task_paths=()
    while IFS= read -r candidate; do
        if [[ "${candidate}" == docs/tasks/${task_prefix}-*.md ]]; then
            task_paths+=("${candidate}")
        fi
    done < <(git ls-tree -r --name-only "refs/heads/${feature_branch}" -- docs/tasks)

    if (( ${#task_paths[@]} != 1 )); then
        fail "feature branch ${feature_branch} must contain exactly one tracked ${task_prefix}-*.md file; found ${#task_paths[@]}."
    fi
    task_path=${task_paths[1]}
    task_content=$(git show "refs/heads/${feature_branch}:${task_path}") || fail \
        "could not read ${task_path} from ${feature_branch}."
    task_status=$(print -r -- "${task_content}" | sed -n '/^Status: / { s/^Status: //; p; q; }')
    [[ "${task_status}" == "Ready for integration" ]] || fail \
        "${task_path} must have Status: Ready for integration; found ${task_status:-missing}."

    feature_worktree=$(feature_worktree_for_branch "${feature_branch}")
    if [[ -n "${feature_worktree}" ]]; then
        [[ -d "${feature_worktree}" ]] || fail \
            "feature branch ${feature_branch} points to missing worktree ${feature_worktree}. Repair or prune that metadata explicitly before integration."
        feature_dirty=$(git -C "${feature_worktree}" status --porcelain=v1 --untracked-files=all) || fail \
            "could not inspect linked feature worktree ${feature_worktree}."
        if [[ -n "${feature_dirty}" ]]; then
            print -u2 -- "${feature_dirty}"
            fail "linked feature worktree ${feature_worktree} has uncommitted changes."
        fi
    fi

    if git merge-base --is-ancestor "refs/heads/${feature_branch}" HEAD; then
        fail "feature branch ${feature_branch} is already contained in main."
    fi
    git merge-base --is-ancestor HEAD "refs/heads/${feature_branch}" || fail \
        "feature branch ${feature_branch} does not contain current main. Merge main into the feature branch, resolve there, and rerun its verification."

    print -r -- "${task_path}"
}

command=${1:-}

case "${command}" in
    check)
        if (( $# == 1 )); then
            assert_primary_checkout false
            print -r -- "main-worktree: verified ${project_root} on ${expected_branch}."
        elif (( $# == 2 )) && [[ "${2}" == --clean ]]; then
            assert_primary_checkout true
            print -r -- "main-worktree: verified clean primary checkout ${project_root} on ${expected_branch}."
        else
            usage
            exit 2
        fi
        ;;
    merge)
        (( $# == 2 )) || {
            usage
            exit 2
        }
        assert_primary_checkout true
        feature_branch=$2
        task_path=$(validate_feature_branch "${feature_branch}")
        print -r -- "main-worktree: merging ${feature_branch} (${task_path}) into ${expected_branch} with --no-ff."
        git merge --no-ff "${feature_branch}"
        print -r -- "main-worktree: merge completed. Verify the merged tree before final Task and STATUS.md updates."
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        exit 2
        ;;
esac

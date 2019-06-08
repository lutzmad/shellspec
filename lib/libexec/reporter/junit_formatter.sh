#shellcheck shell=sh disable=SC2004

: "${field_type:-} ${field_fail:-} ${field_tag:-} ${field_description:-}"
: "${field_lineno:-} ${field_specfile:-} ${field_message:-}"
: "${field_failure_message:-} ${time_real:-}"

junit_testsuite=0 junit_tests=0 junit_failures=0 junit_skipped=0
junit_tests_total=0 junit_failures_total=0
create_buffers junit

junit_output="results_junit.xml"

junit_begin() {
  junit '=' '<?xml version="1.0" encoding="UTF-8"?>'
  junit '+=' "${LF}<testsuites name=\"\">${LF}"
  junit '>>>' >> "$SHELLSPEC_TMPBASE/${junit_output}.work"
}

junit_each() {
  _text='' _attrs='' _testsuite=$junit_testsuite
  _tests=$junit_tests _failures=$junit_failures _skipped=$junit_skipped
  _tests_total=$junit_tests_total _failures_total=$junit_failures_total

  case $field_type in
    meta) junit '=' ;;
    begin)
      htmlattrs _attrs "name=$field_specfile" "hostname=$SHELLSPEC_HOSTNAME" \
        "timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S')"
      junit '=' "  <testsuite $_attrs>${LF}"
      _tests=0 _failures=0 _skipped=0
      ;;
    example)
      htmlattrs _attrs "classname=$field_specfile" "name=$(field_description)"
      junit '=' "    <testcase $_attrs>"
      ;;
    statement)
      if [ "$field_fail" ]; then
        htmlattrs _attrs "message=$field_message"
        _text="$field_failure_message${LF}# $field_specfile:$field_lineno"
        htmlescape _text "$_text"
        junit '=' "${LF}      <failure $_attrs>$_text</failure>${LF}    "
      else
        case $field_tag in (skip | pending)
          htmlattrs _attrs "message=$field_message"
          junit '='  "${LF}      <skip $_attrs />${LF}    "
        esac
      fi
      ;;
    result)
      _tests=$(($_tests + 1))
      _tests_total=$(($_tests_total + 1))
      if [ "$field_fail" ]; then
        _failures=$(($_failures + 1))
        _failures_total=$(($_failures_total + 1))
      else
        case $field_tag in (todo | skipped)
          _skipped=$(($_skipped + 1))
        esac
      fi
      junit '=' "</testcase>${LF}"
      ;;
    end)
      junit '=' "  </testsuite>${LF}"
      eval "junit_tests_${_testsuite}=\$_tests"
      eval "junit_failures_${_testsuite}=\$_failures"
      eval "junit_skipped_${_testsuite}=\$_skipped"
      _testsuite=$(($_testsuite + 1))
      ;;
    finished) junit '=' ;;
  esac
  junit '>>>' >> "$SHELLSPEC_TMPBASE/${junit_output}.work"

  junit_testsuite=$_testsuite
  junit_tests=$_tests junit_failures=$_failures junit_skipped=$_skipped
  junit_tests_total=$_tests_total junit_failures_total=$_failures_total
}

junit_end() {
  junit '=' "</testsuites>${LF}"
  junit '>>>' >> "$SHELLSPEC_TMPBASE/${junit_output}.work"
}

junit_output() {
  _id=0 _before='' _after='' _attrs=''
  case $1 in (end)
    while IFS= read -r _line; do
      case $_line in
        *\<testsuites\ *)
          _before=${_line%%<testsuites\ *} _after=${_line#*<testsuites\ }
          htmlattrs _attrs "tests=$junit_tests_total" \
            "failures=$junit_failures_total" "time=$time_real"
          putsn "$_before<testsuites $_attrs $_after"
          ;;
        *\<testsuite\ *)
          _before=${_line%%<testsuite\ *} _after=${_line#*<testsuite\ }
          eval "htmlattrs _attrs id=$_id tests=\$junit_tests_${_id} \
            failures=\$junit_failures_${_id} skipped=\$junit_skipped_${_id}"
          putsn "$_before<testsuite $_attrs $_after"
          _id=$(($_id + 1))
          ;;
        *) putsn "$_line"
      esac
    done < "$SHELLSPEC_TMPBASE/${junit_output}.work"
  esac
}

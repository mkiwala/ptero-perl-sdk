package Ptero::Test::Integration;

use strict;
use warnings FATAL => 'all';

use Test::More;
use Text::Diff;
use JSON qw(to_json from_json);
use File::Slurp qw(read_file write_file);
use IO::File;
use File::Temp qw(tempfile);
use File::Basename qw(dirname basename);
use File::Spec qw();
use Data::UUID qw();
use Template;

use Ptero::Builder::Workflow;
use Ptero::Builder::ShellCommand;
use Ptero::Test::Utils qw(
    validate_submit_environment
    repo_relative_path
    get_environment
);

use Exporter 'import';
our @EXPORT_OK = qw(
    run_test
);

sub run_test {
    my $file = shift;

    validate_submit_environment();

    my $dir = dirname($file);

    my $submit_file = File::Spec->join($dir, 'submit.json');
    my $workflow_json = get_workflow_json($submit_file);
    my $workflow = Ptero::Builder::Workflow->from_json($workflow_json, 'some-test-workflow');

    my $wf_proxy = $workflow->submit(
        inputs => get_workflow_inputs($workflow_json),
        name => get_test_name(basename($dir)),
    );
    $wf_proxy->wait(polling_interval => 1);

    my $result_file = File::Spec->join($dir, 'result.json');
    is_deeply($wf_proxy->outputs, get_expected_outputs($result_file), 'Got expected outputs');

    compare_workflow_view($dir, $wf_proxy);

    done_testing();
}

sub get_test_name {
    my $base_name = shift;

    my $generator = Data::UUID->new();
    my $uuid = $generator->create();
    return sprintf("Perl SDK Integration Test (%s) %s",
        $base_name, $generator->to_string($uuid));
}

sub compare_workflow_view {
    my ($dir, $wf_proxy) = @_;

    my $concrete_workflow = $wf_proxy->_concrete_workflow(
        get_workflow_skeleton($dir, $wf_proxy),
        get_workflow_executions($dir, $wf_proxy),
    );

    my $expected_file = File::Spec->join($dir, 'workflow-view.txt');
    my $view = $concrete_workflow->view_as_string;

    if ($ENV{PTERO_REGENERATE_TEST_DATA_OUTPUTS}) {
        write_file($expected_file, $view);
    }

    my $diff = diff($expected_file, \$view, { STYLE => "Context" });
    ok(!$diff, 'View looks as expected') || printf "Found differences:\n%s", $diff;
}

sub get_workflow_skeleton {
    my ($dir, $wf_proxy) = @_;

    my $expected_file = File::Spec->join($dir, 'workflow-skeleton.json');

    if ($ENV{PTERO_REGENERATE_TEST_DATA_INPUTS}) {
        my $hashref = $wf_proxy->workflow_skeleton;
        my $json = to_json($hashref, {pretty=>1, canonical=>1});
        write_file($expected_file, $json);
    }

    my $json_text = read_file($expected_file);
    return from_json($json_text);
}

sub get_workflow_executions {
    my ($dir, $wf_proxy) = @_;

    my $expected_file = File::Spec->join($dir, 'workflow-executions.json');

    if ($ENV{PTERO_REGENERATE_TEST_DATA_INPUTS}) {
        my $hashref = $wf_proxy->workflow_executions;
        my $json = to_json($hashref, {pretty=>1, canonical=>1});
        write_file($expected_file, $json);
    }

    my $json_text = read_file($expected_file);
    return from_json($json_text);
}

sub get_workflow_inputs {
    my $workflow_json = shift;

    my $hashref = from_json($workflow_json);
    return $hashref->{inputs} || die "Couldn't find inputs in file '$workflow_json'";
}

sub get_expected_outputs {
    my $filename = shift;

    my $json_text = read_file($filename);
    my $hashref = from_json($json_text);
    note "No outputs found in file '$filename'";
    return $hashref->{outputs};
}

sub get_workflow_json {
    my $submit_file = shift;

    my $template = Template->new({
        START_TAG => quotemeta('{{'),
        END_TAG   => quotemeta('}}'),
    });

    my $vars = {
        user => $ENV{USER},
        environment => to_json(get_environment()),
        workingDirectory => repo_relative_path('bin'),
        webhook => '"'.$ENV{PTERO_WORKFLOW_SUBMIT_URL}.'"',
    };

    my $in_fh = IO::File->new("< $submit_file");

    my $workflow_json;
    $template->process($in_fh, $vars, \$workflow_json)
        || die $template->error();

    return $workflow_json;
}

1;

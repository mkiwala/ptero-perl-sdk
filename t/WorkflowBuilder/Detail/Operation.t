use strict;
use warnings FATAL => 'all';

use Test::Exception;
use Test::More;
use Ptero::WorkflowBuilder::Detail::OperationMethod;


use_ok('Ptero::WorkflowBuilder::Operation');

my $opmethod = {
    name => 'foo',
    submit_url => 'http://example.com',
    parameters => {},
};

{
    my $operation_hashref = {
        methods => [$opmethod],
    };

    my $operation = Ptero::WorkflowBuilder::Operation->from_hashref(
        $operation_hashref, 'squid');

    is_deeply($operation->to_hashref, $operation_hashref,
        'round trip hashref to operation');
};

{
    my $operation_hashref = {
    };

    throws_ok {Ptero::WorkflowBuilder::Operation->from_hashref(
            $operation_hashref, 'bad-methods-in-this-op')}
        qr/Operation hashref must contain a methods arrayref/,
        'no methods in hashref';

    $operation_hashref->{methods} = 'not-an-arrayref';

    throws_ok {Ptero::WorkflowBuilder::Operation->from_hashref(
            $operation_hashref, 'bad-methods-in-this-op')}
        qr/Operation hashref must contain a methods arrayref/,
        'methods is not an arrayref';
};

{
    my $operation_hashref = {
        methods => [],
    };

    my $operation = Ptero::WorkflowBuilder::Operation->from_hashref(
        $operation_hashref, 'halibut');

    is_deeply([$operation->validation_errors],
        ['Operation named "halibut" must have at least one method'],
        'operation must have at least one method');
};

{
    my $operation_hashref = {
        methods => [$opmethod],
    };

    my $operation = Ptero::WorkflowBuilder::Operation->from_hashref(
        $operation_hashref, 'input connector');

    is_deeply([$operation->validation_errors],
        ['Operation may not be named "input connector"'],
        'operation may not be named "input connector"');

    $operation->name('output connector');

    is_deeply([$operation->validation_errors],
        ['Operation may not be named "output connector"'],
        'operation may not be named "output conenctor"');
};

done_testing();

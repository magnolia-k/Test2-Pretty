requires 'Test::More', '0.98';
requires 'Term::Encoding';
requires 'Scope::Guard';

on 'test' => sub {
    requires 'Test::Requires', 0;
};

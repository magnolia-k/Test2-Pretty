requires 'Test::More', '1.302075';
requires 'Term::Encoding';

on 'configure' => sub {
    requires 'ExtUtils::MakeMaker', '6.52';
};

on 'test' => sub {
    requires 'Test::Requires', 0;
};

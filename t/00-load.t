use Test::More tests => 6;

BEGIN {
    use_ok('File::Copy');
    use_ok('File::Spec');
    use_ok('App::ZofCMS::Plugin::Base');
    use_ok('Image::Size');
    use_ok('Image::Resize');
    use_ok( 'App::ZofCMS::Plugin::ImageResize' );
}

diag( "Testing App::ZofCMS::Plugin::ImageResize $App::ZofCMS::Plugin::ImageResize::VERSION, Perl $], $^X" );

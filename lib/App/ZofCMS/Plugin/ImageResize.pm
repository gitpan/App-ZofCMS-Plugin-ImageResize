package App::ZofCMS::Plugin::ImageResize;

use warnings;
use strict;

use Image::Size;
use Image::Resize;
use File::Spec;
use File::Copy;

use base 'App::ZofCMS::Plugin::Base';

our $VERSION = '0.0101';

sub _key { 'plug_image_resize' }
sub _defaults {
    return (
        inplace     => 1,
        only_down   => 1,
        cell        => 'd',
        key         => 'plug_image_resize',
        path        => 'thumbs',
        # images
    );
}
sub _do {
    my ( $self, $conf, $t, $q, $config ) = @_;

    return
        unless defined $conf->{images};

    if ( ref $conf->{images} eq 'CODE' ) {
        $conf->{images} = $conf->{images}->( $t, $q, $config );
    }

    my ( $cell, $key, $images ) = @$conf{qw/cell key images/};

    if ( ref $images eq 'ARRAY' and @$images and ref $images->[0] eq 'ARRAY' ) {
        $t->{$cell}{$key} = [];

        for ( @$images ) {
            push @{ $t->{$cell}{$key} }, _resize_image($_, $t, $conf);
        }
    }
    elsif ( ref $images eq 'HASH' ) {
        $t->{$cell}{$key} = {};

        for ( keys %$images ) {
            $t->{$cell}{$key}{ $_ } = _resize_image( $images->{$_}, $t, $conf );
        }
    }
    else {
        $t->{$cell}{$key} = _resize_image( $images, $t, $conf );
    }
}

sub _resize_image {
    my ( $img, $t, $conf ) = @_;

    my %img;
    if ( ref $img eq 'ARRAY' ) {
        @img{ qw/x y image inplace only_down path/ } = @$img;
    }
    else {
        %img = %$img;
    }

    $img{inplace} = $conf->{inplace}
        unless defined $img{inplace};

    $img{path} = $conf->{path}
        unless defined $img{path};

    $img{only_down} = $conf->{only_down}
        unless defined $img{only_down};

    set_error($t, "Could copy the image $!") and return 
        unless defined $img{image}
            and length $img{image}
            and -e $img{image};

    if ( $img{only_down} ) {
        my ( $x, $y ) = imgsize($img{image});

        if ( $x > $img{x} or $y > $img{y} ) {
            calc_new_dimensions( $x, $y, \%img );
        }
        else {
            @img{ qw/x y/ } = ( $x, $y );
            $img{no_resize} = 1;
        }
    }

    unless ( $img{inplace} ) {
        my $file = ( File::Spec->splitpath($img{image}) )[-1];
        my $resize_file = File::Spec->catfile( $conf->{path}, $file );
        copy $img{image}, $resize_file
            or set_error($t, "Could copy the image $!")
            and return;

        $img{image} = $resize_file;
    }

    unless ( $img{no_resize} ) {
        my $gd = Image::Resize->new( $img{image} )->resize( @img{ qw/x y/ } );

        open my $fh, '>', $img{image}
            or set_error($t, "Could not open image for writing $!")
                and return;

        print $fh $gd->jpeg;
        close $fh;

        @img{ qw/x y/ } = imgsize( $img{image} );
    }

    return \%img;
}

sub calc_new_dimensions {
    my ( $x, $y, $img ) = @_;

    if ( $x > $img->{x} and $y > $img->{y} ) {
        if ( $x - $img->{x} > $y - $img->{y} ) {
            $img->{y} = int($y * $img->{x} / $x);
        }
        else {
            $img->{x} = int($x * $img->{y} / $y);
        }
    }
    elsif ( $x > $img->{x} ) {
        $img->{y} = int($y * $img->{x} / $x);
    }
    else {
        $img->{x} = int($x * $img->{y} / $y);
    }
}

sub set_error {
    my ( $t, $err ) = @_;
    $t->{t}{plug_image_resize_error} = $err;
    return 1;
}


1;
__END__

=head1 NAME

App::ZofCMS::Plugin::ImageResize - Plugin to resize images

=head1 SYNOPSIS


    plugins => [
        qw/ImageResize/
    ],

    plug_image_resize => {
        images => [
            qw/3300 3300 frog.png/
        ],
        # below are all the default values
        inplace     => 1,
        only_down   => 1,
        cell        => 'd',
        key         => 'plug_image_resize',
        path        => 'thumbs',
    },

=head1 DESCRIPTION

The module is a plugin for L<App::ZofCMS> that provides simple image resize capabilities.
This documentation assumes you've read L<App::ZofCMS>, L<App::ZofCMS::Config> and
L<App::ZofCMS::Template>.

=head1 FIRST-LEVEL ZofCMS TEMPLATE AND MAIN CONFIG FILE KEYS

=head2 C<plugins>

    plugins => [
        qw/ImageResize/
    ],

B<Mangatory>. You need to add the plugin to list of plugins to execute.

=head2 C<plug_image_resize>

    plug_image_resize => {
        images => [
            qw/3300 3300 frog.png/
        ],
        # optional options below; all are the default values
        inplace     => 1,
        only_down   => 1,
        cell        => 'd',
        key         => 'plug_image_resize',
        path        => 'thumbs',
    },

B<Mandatory>. Takes a hashref as a value.
The C<plug_image_resize> first-level key can be set in either (or both)
ZofCMS Template and Main Config File files. If set in both, the values of keys that are set in
ZofCMS Template take precedence. Possible keys/values are as follows:

=head3 C<images>

        images => [
            qw/3300 3300 frog.png/
        ],

        images => {
            image1 => {
                x           => 110,
                y           => 110,
                image       => 'frog.png',
                inplace     => 1,
                only_down   => 1,
                path        => 'thumbs',
            },
            image2 => [ qw/3300 3300 frog.png/ ],
        },

        image => [
            [ qw/1000 1000 frog.png/ ],
            [ qw/110 100 frog.png 0 1/ ],
            {
                x           => 110,
                y           => 110,
                image       => 'frog.png',
                inplace     => 1,
                only_down   => 1,
                path        => 'thumbs',
            },
        ],

B<Mandatory>. The C<images> key is the only optional key. Its value can be either an
arrayref, an arrayref of arrayrefs/hashrefs or a hashref.

When value is a hashref, it tells the plugin to resize several images and keys will represent
the names of the keys in the result (see OUTPUT section below) and values are the image
resize options. When value is an
arrayref of scalar values, it tells the plugin to resize only one image and that resize
options are in a "shortform" (see below). When the value is an arrayref of arrayrefs/hashrefs
it means there are several images to resize and each element of the arrayref is an
image to be resized and its resize options are set by each of those inner arrayrefs/hashrefs.

When resize options are given as an arrayref they correspond to the hashref-form keys
in the following order:

    x  y  image  inplace  only_down  path

In other words, the following resize options are equivalent:

    [ qw/100 200 frog.png 0 1 thumbs/ ],

    {
        x           => 110,
        y           => 110,
        image       => 'frog.png',
        inplace     => 1,
        only_down   => 1,
        path        => 'thumbs',
    },

The C<x>, C<y> and C<image> keys are mandatory. The rest of the keys are optional and their
defaults are whatever is set to the same-named keys in the plugin's configuration (see below).
The C<x> and C<y> keys specify the dimensions to which the image should be resized
(see also the C<only_down> option described below). The C<image> key contans the path to
the image, relative to C<index.pl> file.

=head3 C<inplace>

    inplace => 1,

B<Optional>. Takes either true or false values. When set to a true value, the plugin
will resize the images inplace (i.e. the resized version will be written over the original).
When set to a false value, the plugin will first copy the image into directory specified by
C<path> key and then resize it. B<Defaults to:> C<1>

=head3 C<only_down>

    only_down => 1,

B<Optional>. Takes either true or false values. When set to a true value, the plugin will
only resize images if either of their dimensions is larger than what is set in C<x> or C<y>
parameters. When set to a false value, the plugin will scale small images up to meet
the C<x>/C<y> criteria. B<Note:> the plugin will always keep aspect ratio of the images.
B<Defaults to:> C<1>

=head3 C<cell>

    cell => 'd',

B<Optional>. Specifies the name of the first-level key of ZofCMS Template hashref into
which to put the results. Must point to either a non-existant key or a hashref.
B<Defaults to:> C<d>

=head3 C<key>

    key => 'plug_image_resize',

B<Optional>. Specifies the name of the second-level key (i.e. the name of the key inside
C<cell> hashref) where to put the results. B<Defaults to:> C<plug_image_resize>

=head3 C<path>

    path => 'thumbs',

B<Optional>. Specifies the name of the directory, relative to C<index.pl>, into which to
copy the resized images when C<inline> resize option is set to a false value. B<Defaults to:>
C<thumbs>.

=head1 ERRORS ON RESIZE

If an error occured during a resize, instead of a hashref you'll have an C<undef> and the
reason for error will be set to C<< $t->{t}{plug_image_resize_error} >> where C<$t> is the
ZofCMS Template hashref.

=head1 OUTPUT

The plugin will place the output into C<key> hashref key inside C<cell> first-level key
(see parameters above). The type of value of the C<key> will depend on how the C<images>
parameter was set (see dumps below for examples). In either case, each of the resized
images will result in a hashref inside the results. The C<x> and C<y> keys will contain
image's new size. The C<image> key will contain the path to the image relative to C<index.pl>
file. If the image was not resized then the C<no_resize> key will be present and its value
will be C<1>. The C<inplace>, C<path> and C<only_down> keys will be set to the values
that were set to be used in resize options.

    # `images` is set to a hashref with a key named `image1`
    'd' => {
        'plug_image_resize' => {
            'image1' => {
                'inplace' => '0',
                'y' => 2062,
                'path' => 'thumbs',
                'only_down' => '0',
                'x' => 3300,
                'image' => 'thumbs/frog.png'
        }
    }

    # `images` is set to one arrayref (i.e. no inner arrayrefs)
    'd' => {
        'plug_image_resize' => {
            'inplace' => '0',
            'y' => 2062,
            'path' => 'thumbs',
            'only_down' => '0',
            'x' => 3300,
            'image' => 'thumbs/frog.png'
        }
    },

    # `images` is set to one arrayref of arrayrefs
    'd' => {
        'plug_image_resize' => [
            {
                'inplace' => '0',
                'y' => 2062,
                'path' => 'thumbs',
                'only_down' => '0',
                'x' => 3300,
                'image' => 'thumbs/frog.png'
            }
        ],
    },

=head1 AUTHOR

'Zoffix, C<< <'zoffix at cpan.org'> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-zofcms-plugin-imageresize at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-ZofCMS-Plugin-ImageResize>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::ZofCMS::Plugin::ImageResize

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-ZofCMS-Plugin-ImageResize>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-ZofCMS-Plugin-ImageResize>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-ZofCMS-Plugin-ImageResize>

=item * Search CPAN

L<http://search.cpan.org/dist/App-ZofCMS-Plugin-ImageResize/>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2009 'Zoffix, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut


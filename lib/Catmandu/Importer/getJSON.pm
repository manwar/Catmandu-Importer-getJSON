package Catmandu::Importer::getJSON;
#ABSTRACT: Load JSON-encoded data from a server using a GET HTTP request
#VERSION

use Catmandu::Sane;
use Moo;
use Scalar::Util qw(blessed);
use URI::Template;

with 'Catmandu::Importer::HTTP';

has '+headers' => ( is => 'ro', default => sub { [ 'Accept' => 'application/json' ] } );

sub generator {
    my ($self) = @_;

    if ($self->from) {
        return sub {
            state $done = 0;
            return if $done;
            $done = 1;
            return $self->_query_json($self->from);
        }
    }

    sub {
        state $fh   = $self->fh;
        state $data;

        if ( $data and ref $data eq 'ARRAY' and @$data ) {
            return shift @$data;
        }

        my $line = <$fh> // return;
        my $url = $self->_construct_url($line) // return;

        $data = $self->_query_json($url);

        return (ref $data // '') eq 'ARRAY' ? shift @$data : $data;
    }
}

sub _query_json {
    my ($self, $url) = @_;

    my $content = $self->query($url);

    if (defined $content) {
        return $self->json->decode($content->decoded_content);
    }
}

1;

=head1 SYNOPSIS

The following three examples are equivalent:

    Catmandu::Importer::getJSON->new(
        file => \"http://example.org/alice.json\nhttp://example.org/bob.json"
    )->each(sub { my ($record) = @_; ... );

    Catmandu::Importer::getJSON->new(
        url  => "http://example.org",
        file => \"/alice.json\n/bob.json"
    )->each(sub { my ($record) = @_; ... );
    
    Catmandu::Importer::getJSON->new(
        url  => "http://example.org/{name}.json",
        file => \"{\"name\":\"alice\"}\n{\"name\":\"bob\"}"
    )->each(sub { my ($record) = @_; ... );

For more convenience the L<catmandu> command line client can be used:

    echo http://example.org/alice.json | catmandu convert getJSON to YAML
    catmandu convert getJSON --from http://example.org/alice.json to YAML

=head1 DESCRIPTION

This L<Catmandu::Importer> performs a HTTP GET request to load JSON-encoded
data from a server. The importer expects a line-separated input. Each line
corresponds to a HTTP request that is mapped to a JSON-record on success. The
following input formats are accepted:

=over

=item plain URL

A line that starts with "C<http://>" or "C<https://>" is used as plain URL.

=item URL path

A line that starts with "C</>" is appended to the configured B<url> parameter.

=item variables

A JSON object with variables to be used with an URL template or as HTTP query
parameters. For instance the input line C<< {"name":"Karl Marx"} >> with URL
C<http://api.lobid.org/person> or the input line 
C<< {"entity":"person","name":"Karl Marx"} >> with URL template
C<http://api.lobid.org/{entity}{?id}{?name}{?q}> are both expanded to
L<http://api.lobid.org/person?name=Karl+Marx>.

=back

If the JSON data returned in a HTTP response is a JSON array, its elements are
imported as multiple items. If a JSON object is returned, it is imported as one
item.

=head1 CONFIGURATION

=over

=item url

An L<URI> or an URI templates (L<URI::Template>) as defined by 
L<RFC 6570|http://tools.ietf.org/html/rfc6570> to load JSON from. If no B<url>
is configured, plain URLs must be provided as input or option C<from> must be
used instead.

=item from

A plain URL to load JSON without reading any input lines.

=item timeout / agent / proxy / headers

Optional HTTP client settings.

=item client

Instance of a L<Furl> HTTP client to perform requests with.

=item file / fh

Input to read lines from (see L<Catmandu::Importer>). Defaults to STDIN.

=item fix

An optional fix to be applied on every item (see L<Catmandu::Fix>).

=back

=head1 LIMITATIONS

Error handling is very limited.

Future versions of this module may also support asynchronous HTTP fetching
modules such as L<HTTP::Async>, for retrieving multiple URLs at the same time..

=head1 SEE ALSO

L<Catmandu>

=encoding utf8
package Mojolicious::Plugin::Jam::Form::Button;
use Mojo::Base -base;

has type => 'button';
has value => undef;
has id => undef;
has class => undef;
has attribs => sub { {} };

my @types = qw/button submit reset/;
my %allowed_type = map { $_ => 1 } @types;

sub html {
  my $self = shift;
  my $type = $self->type;
  my $value = $self->value;
  my $id = $self->id;
  my $class = $self->class;
  my $attribs = $self->attribs;
  return undef unless defined $type && $allowed_type{$type};
  my $html = "<input";
  $html .= " type=\"$type\"";
  $html .= " id=\"$id\"" if defined $id;
  $html .= " class=\"$class\"" if defined $class;
  $html .= " value=\"$value\"" if defined $value;
  $html .= " $_=\"$attribs->{$_}\"" for sort keys %$attribs;
  $html .= " />";
  return $html;
}

1;

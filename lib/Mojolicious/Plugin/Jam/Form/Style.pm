package Mojolicious::Plugin::Jam::Form::Style;
use Mojo::Base -base;

has _data => sub { {} };
has form => undef;
has name => undef;

sub add {
  my $self = shift;
  my $id = shift;
  push @{$self->_data->{order}}, $id;
  push @{$self->_data->{props}{$id}}, $_ for @_;
}

sub gen {
  my $self = shift;
  my $css;
  for (@{$self->_data->{order}}) {
    $css .= "$_ {\n";
    for (@{$self->_data->{props}{$_}}) {
      $css .= "  $_;\n";
    }
    $css .= "}\n";
  }
  return $css;
}

sub common {
  my $self = shift;
  my $id = shift;
  $self->add(".ui-widget", 'font-size: 75%', 'padding-top: 2px',
    'padding-bottom: 2px');
  $self->add("input.ui-button", 'padding-top: 2px', 'padding-bottom: 2px');
  $self->add("input", 'width: 96%');
  $self->add(
    join(', ', map { "input[type=$_]" } qw/submit reset checkbox/),
    'width: auto'
  );
  $self->add("div#$id", 'display: table', 'border-collapse: collapse; margin-left: auto; margin-right: auto');
  $self->add(".${id}_tooltips", 'background: #ffc'); # , 'max-width: 107px');
  return $self;
}

my %builtin = (
  default => 'vertical',
);

sub builtin {
  my $self = shift;
  my $name = shift || 'default';
  $name = $builtin{$name} || $name;
  $self->name($name);
  my $form = $self->form;
  my $id = defined $form ? $form->id : 'form';

  # Vertical
  if ($name eq 'vertical') {
    $self->_data({});
    $self->common($id);
    $self->add("div.${id}_$_", 'display: table-row') for
      qw/fields buttons/;
    my @cell = ('display: table-cell', 'padding: 5px');
    $self->add("div.${id}_labels", @cell, 'text-align: right');
    $self->add("div.${id}_inputs", @cell);

  # Horizontal
  } elsif ($name eq 'horizontal') {
    $self->_data({});
    $self->common($id);
    $self->add("div.${id}_$_", 'display: table-cell') for
      qw/fields buttons/;
    my @cell = ('padding: 5px');
    $self->add("div.${id}_labels", @cell);
    $self->add("div.${id}_inputs", @cell);
  
  # None
  } elsif ($name eq 'none') {
    $self->_data({});
  }

  return $self;
}

1;

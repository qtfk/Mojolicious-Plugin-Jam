package Mojolicious::Plugin::Jam::Form::Field;
use Mojo::Base -base;

# MODULES

use Time::Local;
use Mojo::JSON 'j';

# OVERLOADED OPERATORS

# Enables using the object as a string scalar to get the HTML tag
use overload '""' => \&html;

# PROPERTIES

has id => 'field';
has type => 'text';
has name => 'field';
has value => undef;
has attribs => sub { {} };
has flags => sub { {} };
has label => 'Field';
has validation_attribs => 0;
has rules => sub { {} };

# ref to parent form
has form => undef;

# validation rules
has validation => sub { [ sub { 1 } ] };

# VARIABLES

# Regular expressions for server-side validation of certain types
my %regex = (
  'email'    => qr/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]+$/i,
  'url'      => qr/^https?:\/\/[A-Z0-9.-]+\.[A-Z]+/i,
  'date'     => qr/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/,
  'datetime' => qr/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]Z$/,
  'datetime-local' => qr/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]$/,
  #'' => qr//,
);

# Subroutines for server-side validation of certain types
# These are used instead of or in addition to regex's to provide a different approach for validating the field value
my %sub = (
  'date' => sub {
    my $v = shift;
    $v = '' unless defined $v;
    my ($y, $m, $d) = split /-/, $v;
    eval "timelocal 0, 0, 0, $d, $m - 1, $y";
    $@ ? 0 : 1;
  },
  'datetime' => sub {
    my $v = shift;
    $v = '' unless defined $v;
    my ($date, $time) = split /T/, $v;
    my ($y, $m, $d) = split /-/, $date;
    $time =~ s/Z$//;
    my ($H, $M, $S, $SS) = split /[:\.]/, $time;
    my $t = gmtime(eval "timegm $S, $M, $H, $d, $m - 1, $y" || 0);
    #print "\$t = \"$t\"\n";
    $@ ? 0 : 1;
  },
  'datetime-local' => sub {
    my $v = shift;
    $v = '' unless defined $v;
    my ($date, $time) = split /T/, $v;
    my ($y, $m, $d) = split /-/, $date;
    my ($H, $M, $S, $SS) = split /[:\.]/, $time;
    my $t = localtime(eval "timelocal $S, $M, $H, $d, $m - 1, $y" || 0);
    #print "\$t = \"$t\"\n";
    $@ ? 0 : 1;
  },
  #'email' => sub {}, # validate that the email address actually exists; perhaps incorporate an email address verification process so the user cannot continue until the address has been verified?
  #'' => sub {},
);

# Non-input tag fields
my %tag = map { $_ => $_ } qw/textarea select/;

# Allowed types
my @types = (qw/text email url date datetime-local month week time number/,
             qw/range password file search color/,
             qw/submit reset button/);
             #qw/checkbox radio textarea select hidden/
my %allowed_type = map { $_ => 1 } @types;

# Types for jQuery validate plugin's validate() function
my %val_type = (date => 'dateISO');
$val_type{$_} = $_ for qw/email url/;

# VALIDATION METHODS

sub minlength {
  my ($self, $min) = @_;

  # Server-side validation
  push @{$self->validation}, sub {
    my $l = length shift;
    defined $l ? $l >= $min : undef;
  };

  # Client-side validation
  my $name = $self->name;
  my $form = $self->form;
  my $validation_attribs = $self->validation_attribs;
  if (defined $form) {
    $form->_validate->{rules}{$name}{minlength} = $min;
  } elsif (defined $validation_attribs && $validation_attribs) {
    $self->attribs->{minlength} = $min;
  } else {
    $self->rules->{minlength} = $min;
  }

  return $self;
}

sub maxlength {
  my ($self, $max) = @_;

  # Server-side validation
  push @{$self->validation}, sub {
    my $l = length shift;
    defined $l ? $l <= $max : 1;
  };

  # Client-side validation
  my $name = $self->name;
  my $form = $self->form;
  my $validation_attribs = $self->validation_attribs;
  if (defined $form) {
    $form->_validate->{rules}{$name}{maxlength} = $max;
  } elsif (defined $validation_attribs && $validation_attribs) {
    $self->attribs->{maxlength} = $max;
  } else {
    $self->rules->{maxlength} = $max;
  }

  return $self;
}

sub rangelength {
  my ($self, $min, $max) = @_;

  # Server-side validation
  push @{$self->validation}, sub {
    my $l = length shift;
    defined $l ? $l >= $min && $l <= $max : undef;
  };

  # Client-side validation
  my $name = $self->name;
  my $form = $self->form;
  my $validation_attribs = $self->validation_attribs;
  if (defined $form) {
    $form->_validate->{rules}{$name}{rangelength} = [$min, $max];
  } elsif (defined $validation_attribs && $validation_attribs) {
    $self->attribs->{minlength} = $min;
    $self->attribs->{maxlength} = $max;
  } else {
    $form->rules->{rangelength} = [$min, $max];
  }

  return $self;
}

sub min {
  my ($self, $min) = @_;
  my $type = $self->type;

  die "Type $type cannot use min!\n"
    unless $type =~ /^(number|range)$/;

  # Server-side validation
  push @{$self->validation}, sub {
    my $v = shift;
    defined $v ? $v >= $min : undef;
  };

  # Client-side validation
  my $name = $self->name;
  my $form = $self->form;
  my $validation_attribs = $self->validation_attribs;
  if (defined $form) {
    $form->_validate->{rules}{$name}{min} = $min;
  } elsif (defined $validation_attribs && $validation_attribs) {
    $self->attribs->{min} = $min;
  } else {
    $self->rules->{min} = $min;
  }

  return $self;
}

sub max {
  my ($self, $max) = @_;
  my $type = $self->type;
  
  die "Type $type cannot use max!\n"
    unless $type =~ /^(number|range)$/;

  # Server-side validation
  push @{$self->validation}, sub {
    my $v = shift;
    defined $v ? $v <= $max : undef;
  };

  # Client-side validation
  my $name = $self->name;
  my $form = $self->form;
  my $validation_attribs = $self->validation_attribs;
  if (defined $form) {
    $form->_validate->{rules}{$name}{max} = $max;
  } elsif (defined $validation_attribs && $validation_attribs) {
    $self->attribs->{max} = $max;
  } else {
    $self->rules->{max} = $max;
  }

  return $self;
}

sub step {
  my ($self, $step) = @_;
  my $type = $self->type;

  die "Type $type cannot use step!\n"
    unless $type =~ /^(number|range)$/;

  # Server-side validation
  push @{$self->validation}, sub {
    my $v = shift;
    defined $v ? $v % $step == 0 : undef;
  };

  # Client-side validation
  my $name = $self->name;
  my $form = $self->form;
  my $validation_attribs = $self->validation_attribs;
  if (defined $form) {
    $form->_validate->{rules}{$name}{step} = $step;
  } elsif (defined $validation_attribs && $validation_attribs) {
    $self->attribs->{step} = $step;
  } else {
    $self->rules->{step} = $step;
  }

  return $self;
}

sub range {
  my ($self, $min, $max) = @_;
  my $type = $self->type;

  die "Type $type cannot use range!\n"
    unless $type =~ /^(number|range)$/;

  # Server-side validation
  push @{$self->validation}, sub {
    my $v = shift;
    defined $v ? $v >= $min && $v <= $max : undef;
  };

  # Client-side validation
  my $name = $self->name;
  my $form = $self->form;
  my $validation_attribs = $self->validation_attribs;
  if (defined $form) {
    $form->_validate->{rules}{$name}{range} = [$min, $max];
  } elsif (defined $validation_attribs && $validation_attribs) {
    $self->attribs->{min} = $min;
    $self->attribs->{max} = $max;
  } else {
    $self->rules->{rules} = [$min, $max];
  }

  return $self;
}

sub required {
  my $self = shift;

  # Server-side validation
  push @{$self->validation}, sub { defined shift };

  # Client-side validation
  my $name = $self->name;
  my $form = $self->form;
  my $validation_attribs = $self->validation_attribs;
  if (defined $form) {
    $form->_validate->{rules}{$name}{required} = Mojo::JSON->true;
  } elsif (defined $validation_attribs && $validation_attribs) {
    $self->flags->{required} = 1;
  } else {
    $self->rules->{required} = Mojo::JSON->true;
  }

  return $self;
}

sub autofocus {
  my $self = shift;
  $self->flags->{autofocus} = 1;
  return $self;
}

sub checked {
  my $self = shift;
  $self->flags->{checked} = 1;
  return $self;
}

# GENERATE

sub html {
  my $self = shift;

  my $id      = $self->id;
  my $type    = $self->type;
  my $name    = $self->name;
  my $value   = $self->value;
  my $attribs = $self->attribs;
  my $flags   = $self->flags;
  my $form    = $self->form;
  my $label   = $self->label;

  $name = undef if $type =~ /^(submit|reset)$/;

  my $formid = $form->id if defined $form;

  die "FATAL: Field does not have an id!\n"
    unless defined $id && $id;

  die "FATAL: Field does not have an name!\n"
    unless $type =~ /^(submit|reset)$/ || defined $name && $name;

  die "FATAL: Field type \"$type\" is not recognized!\n"
    unless $allowed_type{$type};

  # Add type-based rules to the form validate function rules
  my $val_type = $val_type{$type};
  if (defined $val_type) {
    if (defined $form) {
      $form->_validate->{rules}{$name} = {
        #required => Mojo::JSON->true,
        $val_type => Mojo::JSON->true,
      };
    } else {
      $self->rules->{$val_type} = Mojo::JSON->true;
    }
  }

  my $html;

  # Label
  if (defined $label) {
    my $class = defined $formid ? " class=\"${formid}_labels\"" : '';
    my $l = "<div id=\"${id}_label\"$class>";
    $l .= "<label for=\"$id\" id=\"${id}_label\"$class>$label</label>";
    $l .= "</div>\n";
    $html .= $l;
  }

  # Input
  my $class = defined $formid ? " class=\"${formid}_inputs\"" : '';
  my $input = "<div id=\"${id}_input\"$class>";
  $input .= "<input type=\"$type\" id=\"$id\"$class";
  $input .= " name=\"$name\"" if defined $name;
  $input .= " $_=\"$attribs->{$_}\"" for sort keys %$attribs;
  $input .= " $_" for sort keys %$flags;
  $input .= " value=\"$value\"" if defined $value;
  $input .= " /></div>\n";
  $html .= $input;

  # Script
  if (! defined $form && keys %{$self->rules}) {
    my $script = "<script>\$(input#" . $self->id . "\").rules(\"add\", ";
    $script .= j($self->rules) . ");</script>\n";
    $html .= $script;
  }

  # Wrap up in a div
  $class = defined $formid ? " class=\"${formid}_fields\"" : '';
  $html = "<div id=\"$id\"$class>\n$html</div>";

  return $html;
}

# SERVER-SIDE VALIDATION

sub valid {
  my $self = shift;

  my $type = $self->type;
  my $value = $self->value;
  my $flags = $self->flags;
  my $validation = $self->validation;

  return undef unless $allowed_type{$type};

  # Add regular expression to the list of validation subroutines
  my $regex = $regex{$type};
  if (defined $regex) {
    if (defined $value || $flags->{required}) {
      push @$validation, sub {
        my $v = shift;
        my $default = ! $flags->{required};
        my $r = defined $v ? $v =~ /$regex/ : $default;
        return $r;
      };
    }
  }

  # Add subroutine to the list of validation subroutines
  my $sub = $sub{$type};
  if (defined $sub) {
    if (defined $value || $flags->{required}) {
      push @$validation, $sub;
    }
  }

  # Run each validation subroutine, first failure fails
  for (@$validation) {
    return 0 unless $_->($value);
  }

  # Return true if passed all validation subroutines
  return 1;
}

1;
__END__

=head1 NAME

Mojolicious::Plugin::Jam::Form::Field - HTML form field object

=head1 SYNOPSIS

 my $field = Mojolicious::Plugin::Jam::Form::Field->new;
 
 print "$field\n";
 # prints "<input type=\"text\" />\n"

 $field->name('a');
 $field->type('email');
 
 print "$field\n";
 # print "<input type=\"email\" name=\"a\" />\n"

 # In controller:
 $self->stash(field => $field);

 # In view:
 %== $field

 # Server-side validation
 my $field = $self->stash('field');
 $field->value($self->param($field->name)); # set the value from param()
 if ($field->valid) {
   # do something
 } else {
   # do something else
 }

=head1 DESCRIPTION

Mojolicious::Plugin::Jam::Form::Field provides an object-based representation
of an HTML form field.

It exhibits the following features:

=over

=item *

Modern Perl-ish API allows method chaining

=item *

2 mechanisms for client-side validation: HTML5 attributes and jQuery
Validate Plugin

=item *

2 mechanisms for server-side validation: regular expressions and
subroutines

=item *

All 4 validation mechanisms are enabled via the initial definition of the field's criteria

=back

Each field consists of 4 distinct elements: label, input, error and script.
Each of these elements are wrapped in a div.
Each div is subsequently wrapped in another div representing the entire
field.
This organization allows the Mojolicious developer to focus on the
characteristics of the field, as well as the web designer to craft CSS for
styling the form.
Each distinct element shares a class with other form elements enabling
precise control over all elements in the field and across all fields in the
form.

=head1 PROPERTIES

=head2 id

Get/set the field id

=head2 type

Get/set the field type

=head2 name

Get/set the field name

=head2 value

Get/set the field value

=head2 attribs

Get/set/add to the field attributes hashref

=head2 flags

Get/set/add to the field flag attributes hashref

=head2 label

Get/set the field label

=head2 validation_attribs

If true, force use of HTML5 validation attributes instead of using the jQuery
Validate Plugin

=head2 rules

Get/set/add to the field validation rules for client-side validation

=head2 validation

Get/set/add to the field validation arrayref of anonymous subroutines for
server-side validation

=head2 form

Reference to a parent L<Mojolicious::Plugin::Jam::Form::Form> object

=head1 METHODS

=head2 html

Generate and return the HTML for the field. This method is called when the object
is treated as a string via overloading.

=head2 valid

Runs each validation subroutine in the field's validation arrayref of anonymous
subroutines. Returns 0 if any fails, 1 if all pass.

=head2 VALIDATION

The following are methods used to configure the validation of fields.
Each one sets either HTML5 validation attributes or jQuery Validate Plugin
rules and server-side validation subroutines.
All return the field object to allow method chaining, i.e.:

 $field->minlength(3)->required;

Note that calling the same validation method more than once for a field may
have undesirable effects since each one pushes server-side validation 
subroutines to the field validation arrayref, which are run in order and
all must pass to be declared valid.

=head3 minlength

Define a minimum length for a field

 $field->minlength($min);

=head3 maxlength

Define a maximum length for a field

 $field->maxlength($max);

=head3 rangelength

Define a length range (minimum and maximum) for a field

 $field->rangelength($min, $max);

=head3 min

Define a minimum numerical value for a field.
Valid for number and range types.

 $field->min($min);

=head3 max

Define a maximum numerical value for a field.
Valid for number and range types.

 $field->max($max);

=head3 step

Define a step value for a field.
Valid for number and range types.

 $field->step($step);

=head3 range

Define a numerical range (minimum and maximum) for a field.
Valid for number and range types.

 $field->range($min, $max);

=head3 required

Define a field to be required (defined)

 $field->required;

=head2 OTHER

=head3 autofocus

Set field to have autofocus

 $field->autofocus;

=head3 checked

Set field to be checked

 $field->checked;

=head1 SEE ALSO

L<Mojolicious::Plugin::Jam>,
L<Mojolicious::Plugin::Jam::Form>,
L<Mojolicious::Plugin::Jam::Form::Button>,
L<Mojolicious::Plugin::Jam::Form::Style>

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=head1 SOURCE REPOSITORY

http://github.com/qtfk/Mojolicious-Plugin-Jam

=head1 AUTHOR

qtfk, <mojolicious-plugin-jam@qtfk.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by qtfk

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

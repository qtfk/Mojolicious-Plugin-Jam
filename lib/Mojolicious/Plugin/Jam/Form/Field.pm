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
has _required => 0;
has desc => undef; # only used by checkbox, radio

# ref to parent form
has form => undef;

# validation rules
has validation => sub { [ sub { 1 } ] };

# VARIABLES

# Regular expressions for server-side validation of certain types
my %regex = (
  'email'  => qr/^[\dA-Z._%+-]+@[\dA-Z.-]+\.[A-Z]+$/i,
  'url'    => qr/^(https?|ftp):\/\/[\dA-Z.-]+\.[A-Z]+/i,
  'date'   => qr/^\d{4}-\d{2}-\d{2}$/,
  'month'  => qr/^\d{4}-\d{2}$/,
  'week'   => qr/^\d{4}-W\d{2}$/,
  'time'   => qr/^\d{2}:\d{2}$/,
  'number' => qr/^\d+(\.\d+)?$/,
  'range'  => qr/^\d+(\.\d+)?$/,
  'color'  => qr/^#[\da-f]{6}$/i,
  'datetime-local' =>
    qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(.\d)?$/,
  #'' => qr//,
);

# Subroutines for server-side validation of certain types
# These are used in addition to regex's to provide a different approach for
# validating the field value
my %sub = (
  #'email' => sub {}, # validate that the email address actually exists; perhaps incorporate an email address verification process so the user cannot continue until the address has been verified?
  #'url' => sub {}, # validate the url is live? use Mojo::UserAgent
  'date' => sub {
    my $v = shift;
    $v = '' unless defined $v;
    my ($y, $m, $d) = split /-/, $v;
    eval "timelocal 0, 0, 0, $d, $m - 1, $y";
    return $@ ? 0 : 1;
  },
  'datetime-local' => sub {
    my $v = shift;
    $v = '' unless defined $v;
    my ($date, $time) = split /T/, $v;
    my ($y, $m, $d) = split /-/, $date;
    my ($hms, $ss) = split /\./, $time;
    my ($H, $M, $S) = split /:/, $hms;
    $S = 0 unless defined $S;
    eval "timelocal $S, $M, $H, $d, $m - 1, $y";
    return $@ ? 0 : 1;
  },
  'month' => sub {
    my $v = shift;
    my ($y, $m) = split /-/, $v;
    eval "timelocal 0, 0, 0, 1, $m - 1, $y";
    return $@ ? 0 : 1;
  },
  'week' => sub {
    my $v = shift;
    my ($y, $w) = split /-W0?/, $v;
    eval "timelocal 0, 0, 0, 1, 0, $y";
    return $w >= 1 && $w <= 52 && ! $@;
  },
  'time' => sub {
    my $v = shift;
    my ($h, $m) = split /:/, $_;
    s/^0+// for $h, $m;
    return $h >= 0 && $h <= 23 && $m >= 0 && $m <= 59;
  },
  #'number' => sub {},
  #'range' => sub {},
  #'color' => sub {},
  #'' => sub {},
);

# Allowed types
my @types = (qw/text email url date datetime-local month week time number/,
             qw/range password file search color hidden checkbox/,
             # checkbox radio textarea select
             qw/submit reset button/);
my %allowed_type = map { $_ => 1 } @types;

# Types for jQuery validate plugin's validate() function
my %val_type = (date => 'dateISO');
$val_type{$_} = $_ for qw/email url number/;

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
  $self->_required(1);

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
  my $desc    = $self->desc;

  $name = undef if $type =~ /^(submit|reset)$/;

  my $formid = $form->id if defined $form;

  die "FATAL: Field does not have an id!\n"
    unless defined $id && $id;

  die "FATAL: Field does not have an name!\n"
    unless $type =~ /^(submit|reset)$/ || defined $name && $name;

  die "FATAL: Field type \"$type\" is not recognized!\n"
    unless $allowed_type{$type};

  # Add type-based rules to the jQuery validation plugin validate function
  # rules
  my $val_type = $val_type{$type};
  if (defined $val_type) {
    if (defined $form) {
      $form->_validate->{rules}{$name}{$val_type} = Mojo::JSON->true;
    } else {
      $self->rules->{$val_type} = Mojo::JSON->true;
    }
  }

  my $html;

  # Label
  if (defined $label && $type ne 'hidden') {
    my $class = defined $formid ? " class=\"${formid}_labels\"" : '';
    my $l = "<div id=\"${id}_label\"$class>";
    $l .= "<label for=\"$id\" id=\"${id}_label\"$class>$label</label>";
    $l .= "</div>\n";
    $html .= $l;
  }

  # Input
  my $class = defined $formid ? " class=\"${formid}_inputs\"" : '';
  my $input = "<input type=\"$type\" id=\"$id\"$class";
  $input .= " name=\"$name\"" if defined $name;
  $input .= " $_=\"$attribs->{$_}\"" for sort keys %$attribs;
  $input .= " $_" for sort keys %$flags;
  $input .= " value=\"$value\"" if defined $value && $type ne 'password';
  $input .= " />";
  $input .= " $desc" if defined $desc;
  $input = "<div id=\"${id}_input\"$class>$input</div>\n"
    unless $type eq 'hidden';
  $html .= $input;

  # Script
  if (! defined $form && keys %{$self->rules} && $type ne 'hidden') {
    my $script = "<script>\$(input#" . $self->id . "\").rules(\"add\", ";
    $script .= j($self->rules) . ");</script>\n";
    $html .= $script;
  }

  # Wrap up in a div
  unless ($type eq 'hidden') {
    my $class = defined $formid ? " class=\"${formid}_fields\"" : '';
    $html = "<div id=\"$id\"$class>\n$html</div>";
  }

  return $html;
}

# SERVER-SIDE VALIDATION

sub valid {
  my $self = shift;

  my $type = $self->type;
  my $value = $self->value;
  my $flags = $self->flags;
  my @validation = @{$self->validation};

  return undef unless $allowed_type{$type};

  # Add regular expression to the list of validation subroutines
  my $regex = $regex{$type};
  push @validation, sub { shift =~ /$regex/ }
    if defined $regex && $self->_required;

  # Add subroutine to the list of validation subroutines
  my $sub = $sub{$type};
  push @validation, $sub if defined $sub && $self->_required;

  # Run each validation subroutine, first failure fails
  for (@validation) {
    return 0 unless $_->($value);
  }

  # Return true if passed all validation subroutines
  return 1;
}

1;

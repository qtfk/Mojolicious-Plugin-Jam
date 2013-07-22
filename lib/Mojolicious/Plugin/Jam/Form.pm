package Mojolicious::Plugin::Jam::Form;
use Mojo::Base -base;

use Mojolicious::Plugin::Jam::Form::Field;
use Mojolicious::Plugin::Jam::Form::Style;
use Mojolicious::Plugin::Jam::Form::Button;

use Mojo::JSON 'j';

use overload '""' => \&html;

# PROPERTIES

has id => 'form';
has action => undef;
has method => 'AJAX';
has fields => sub { [] };
has fields_hash => sub { {} };
has hiddens => sub { [] };
has buttons => sub { [] };
has style => sub {
  my $self = shift;
  my $style = Mojolicious::Plugin::Jam::Form::Style->new(form => $self);
  $style->builtin('default');
  return $style;
};
#has ajax => undef;
has redirect => '';

# autogenerate field names
has _names => sub { {} };
has _name => 'a';

# jquery validate plugin's validate function
has _validate => sub { {} };

# METHODS

sub get {
  my $self = shift;
  $self->method('GET');
  return $self;
}

sub post {
  my $self = shift;
  $self->method('POST');
  return $self;
}

sub field {
  my $self = shift;

  # This subroutine is a shortcut for:
  # use Mojolicious::Plugin::Jam::Form::Field;
  # my $field = Mojolicious::Plugin::Jam::Form::Field->new;
  # $field->form($form);
  # push @{$form->fields}, $field;
  # $form->_names->{$field->name} = 1;
  # 
  # It also provides some error checking, such as autogenerating and
  # deconflicting field names.

  my $field = Mojolicious::Plugin::Jam::Form::Field->new(
    form => $self, @_);

  # If field doesn't have a name, generate a one-up name in the range a, b,
  # ..., z, aa, ab, ...:
  my $name = $field->name;
  if ($field->type =~ /^(submit|reset)$/) {
    $field->id($1);
    $name = undef;
  } elsif ($name eq 'field') {
    my $i = $self->_name;
    $name = $i++;
    $self->_name($i);
  }

  # We can give it a name later, but the generated one will have already
  # been used. This is a subtle difference between
  # "$form->field(name => $name)" and "$form->field->name($name)".
  # In the former case the name would not be generated, but in the latter
  # case the initial name would be generated, then redefined.
  #
  # Similarly, we can void autonaming submit and reset fields by providing
  # the type as an argument to field(): "$form->field(type => 'submit')"
  # rather than "$form->field->type('submit')".

  # Deconflict field name
  if (defined $name) {
    if ($self->_names->{$name}) {
      die "Field with name \"$name\" already exists!\n";
    }
    $field->name($name);
    $field->id($name) if $field->id eq 'field';
    $self->_names->{$name} = 1;
  }

  # Add the field
  if ($field->type eq 'hidden') {
    push @{$self->hiddens}, $field;
  } else {
    push @{$self->fields}, $field;
  }
  $self->fields_hash->{$field->name} = $field;

  return $field;
}

sub button {
  my $self = shift;
  my %o = @_;
  my $id = $self->id;
  $o{class} = "${id}_inputs";
  my $button = Mojolicious::Plugin::Jam::Form::Button->new(%o);
  push @{$self->buttons}, $button;
  return $button;
}

# BUILT-IN FIELDS

my %bi_label = (
  url => 'URL',
);
my %val_desc = (
  email => 'email address',
);
my %bi_type = (
  datetime => 'datetime-local',
);
sub _bi_field {
  my ($self, $type, %o) = @_;
  $o{type} = $bi_type{$type} || $type;
  $o{label} ||= $bi_label{$type} || ucfirst $type;
  $o{$_} ||= $type for qw/id name/;
  my $desc = $val_desc{$type} || $bi_label{$type} || $type;
  $self->_validate->{messages}{$o{name}}{$type} =
    "Please enter a valid $desc.";
  return $self->field(%o);
}
my @types = (qw/text email url date datetime month week time number/,
             qw/range password file search color checkbox/);
             # checkbox radio textarea select
eval "sub $_ { shift->_bi_field('$_', \@_) }" for @types;

sub hidden {
  my ($self, %o) = @_;
  $o{type} = 'hidden';
  return $self->field(%o);
}

# Common fields
my @common = qw/username/;
$bi_type{$_} = 'text' for @common;
eval "sub $_ { shift->_bi_field('$_', \@_) }" for @common;

# BUILT-IN BUTTONS

sub _bi_button {
  my ($self, $type, %o) = @_;
  $o{$_} = $type for qw/id type/;
  $o{value} = 'Submit' if $type eq 'submit';
  return $self->button(%o);
}
my @buttons = qw/submit reset/;
eval "sub $_ { shift->_bi_button('$_', \@_) }" for @buttons;

# GENERATION

sub html {
  my $self = shift;

  my $id = $self->id;
  my $method = uc $self->method;
  my $action = $self->action;
  my $ajax = undef; #$self->ajax;
  my $redirect = $self->redirect;

  die "FATAL: Form does not have an id!\n" unless defined $id && $id;

  my $html;

  # CSS
  my $style = $self->style;
  if (defined $style) {
    if (ref $style eq 'Mojolicious::Plugin::Jam::Form::Style') {
      $html .= "<style>\n" . $style->gen . "</style>\n";
    }
  }

  # Start form tag
  $html .= "<form";
  $html .= " id=\"$id\"";
  if (defined $method && $method =~ /^(GET|POST)$/) {
    $html .= " method=\"$method\"";
    $html .= " action=\"$action\"" if defined $action;
  }
  $html .= ">\n";

  # Fields
  for (@{$self->fields}) {
    $html .= "$_\n";
  }

  # Buttons
  if (@{$self->buttons}) {
    $html .= <<HTML;
<div id="buttons" class="${id}_buttons">
<div id="buttons_label" class="${id}_labels">&nbsp;</div>
<div id="buttons_input" class="${id}_inputs">
HTML
    for (@{$self->buttons}) {
      $html .= $_->html . "\n";
    }
    $html .= "</div>\n</div>\n";
  }

  # Hidden fields
  if (@{$self->hiddens}) {
    $html .= "<div id=\"${id}_hiddens\">\n";
    $html .= "$_\n" for @{$self->hiddens};
    $html .= "</div>\n";
  }

  # End form tag
  $html .= "</form>\n";

  # jQuery UI buttons and tooltips
  # jQuery validate plugin validate()
  my $buttons = join ', ', map { "form#$id input[type=$_]" }
                             qw/button submit reset/;
  my $position = 'my: "left center", at: "right+10 center"';
  $position = 'my: "left top", at: "left+5 bottom+10"'
    if $style->name eq 'horizontal';
  $position .= ", of: \$(this).parent(\"div.${id}_inputs\")";
  my $maxwidth = '';
  $maxwidth = "var width = \$(el).width() - 15;
        \$(el).on(\"tooltipopen\", function(ev, ui) {
          ui.tooltip.css(\"max-width\", width);
        });\n        " if $style->name eq 'horizontal';
  my $script = <<HTML;
<script>
  \$(function () {
    \$("$buttons").button();
    \$("form#$id input").each(function(i) {
      var position = {$position, collision: "none"};
      \$(this).tooltip({
        position: position,
        tooltipClass: "${id}_tooltips",
      });
    });
    \$("form#$id input").mouseout(function (e) {
      e.stopImmediatePropagation();
    });
    \$("form#$id").validate({
      "errorPlacement": function(err, el) {
        \$(el).prop("title", err.text());
        $maxwidth\$(el).tooltip("open");
      },
      "success": function(label, el) {
        \$(el).tooltip("close").prop("title", "");
      },
HTML
  # Add rules and messages
  if (keys %{$self->_validate}) {
    my $v = j($self->_validate);
    $v =~ s/^{//;
    $v =~ s/}$//;
    $v =~ s/:/: /g;

    # JSON pretty printer
    my $i = 3;
    my $v2;
    for my $c (split //, $v) {
      if ($c eq '{') {
        $c = "{\n" . '  ' x ++$i;
      } elsif ($c eq '}') {
        $c = "\n" . ('  ' x --$i) . $c;
      } elsif ($c eq ',') {
        $c = ",\n" . '  ' x $i;
      }
      $v2 .= $c;
    }
    $v = $v2;

    $script .= "      $v,";
  }
  if ($method eq 'AJAX') {
    $ajax ||= <<JAVASCRIPT;
function(d) {
  console.log('AJAX Responded', d);
  //if (d.status == \"success\") {
  //  location.href = "$redirect";
  //} else {
    clearInterval(timer);
    // Dialog?
    console.log("submit_val = \\"" + submit_val + "\\"");
    submit.val(submit_val);
    \$("form#$id input").removeAttr('disabled');
  //}
}
JAVASCRIPT
    $ajax = "    " . join "\n    ", split /\n/, $ajax;
    my $submit = <<JAVASCRIPT;
"submitHandler": function(form) {
  var fields = \$("form#$id").serialize();
  console.log(fields);
  \$("form#$id input").blur().attr('disabled', 'disabled');
  var spinner = ['◐', '◓', '◑', '◒'];
  var i = 0;
  var submit = \$("form#$id input[type=submit]");
  var submit_val = submit.attr('value');
  console.log("submit_val = \\"" + submit_val + "\\"");
  var timer = setInterval(function() {
    var spin = spinner[i++ % spinner.length];
    //console.log(spin);
    submit.attr('value', spin);
  }, 100);
  console.log('Sending via AJAX POST');
  \$.post("$action", fields).done(
$ajax
  );
  return false;
},
JAVASCRIPT
    $submit = "      " . join "\n      ", split /\n/, $submit;
    $script .= "\n$submit";
  }
  $script .= "\n    });\n  });\n</script>";
  $html .= $script;

  # Wrap up in a div
  $html = "<div id=\"$id\">\n$html</div>";

  return $html;
}

# SET VALUES

sub values {
  my $self = shift;
  my $c = shift;
  #if (@_) {
  #  # Set and return the fields w/ passed names
  #  my @r;
  #  for (@_) {
  #    my $field = $self->fields_hash->{$_};
  #    my $value = $c->param($_);
  #    $field->value($value);
  #    push @r, $value;
  #  }
  #  return @r > 1 ? @r : $r[0];
  #} else {
    
    for my $field (@{$self->fields}) {
      #next if $field->type eq 'password';
      $field->value($c->param($field->name));
    }
    return $self;
  #}
  #return undef;
}

# SERVER SIDE VALIDATION

sub valid {
  my $self = shift;
  if (@_) {
    # Validate just the fields w/ the passed names
    for (@_) {
      my $field = $self->fields_hash->{$_};
      return 0 unless $field->valid;
    }
  } else {
    # Validate all the fields
    for (@{$self->fields}) {
      return 0 unless $_->valid;
    }
  }
  return 1;
}

1;
__END__

=head1 NAME

Mojolicious::Plugin::Jam::Form - HTML form object

=head1 SYNOPSIS

 my $form = Mojolicious::Plugin::Jam::Form->new;
 
 # Add and configure fields
 $form->field;
 
 # Generate html
 print $form->html;
 print "$form";
 
 # Set values from param
 $form->values($self);
 
 # Validate form
 if ($form->valid) {
   # do something
 } else {
   # do something else
 }

=head1 DESCRIPTION

L<Mojolicious::Plugin::Jam::Form> provides an object-based
representation of an HTML form for use with the 'form' command in
L<Mojolicious::Plugin::Jam>.

It exhibits the following features:

=over

=item *

Modern Perl-ish API allows method chaining

=back

=head1 PROPERTIES

=head2 id

Get/set the form id

=head2 action

Get/set the form action

=head2 method

Get/set the form method

=head2 fields

Get/set/append to form fields arrayref

=head1 METHODS

=head2 get

Set form method to 'GET'. Returns L<Mojolicious::Plugin::Jam::Form>
object.

=head2 post

Set form method to 'POST'

=head2 field

Create and configure a L<Mojolicious::Plugin::Jam::Form::Field|http://qtfk.github.io/Mojolicious-Plugin-Jam/Form/Field> object and
add to the form object. Returns the L<Mojolicious::Plugin::Jam::Form::Field|http://qtfk.github.io/Mojolicious-Plugin-Jam/Form/Field>
object.

=head2 html

Generate and return the HTML for the form. This method is called when the
object is treated as a string via overloading.

=head2 values

Set values from the controller prior to performing validation.

=head2 valid

Call the valid method on each L<Mojolicious::Plugin::Jam::Form::Field|http://qtfk.github.io/Mojolicious-Plugin-Jam/Form/Field> object in
the form. Returns 0 if any fails, 1 if all pass.

=head1 BUILT-IN FIELDS

Built-in fields are extremely common fields which should help enable
Mojolicious developers to rapidly assemble forms. In time, the number of
built-in fields should grow.

=head2 text

Creates and adds a text input field to the form

=head2 username

Creates and adds a username input field to the form

=head2 password

Creates and adds a password input field to the form

=head2 submit

Creates and adds a submit button to the form

=head2 reset

Create and adds a reset button to the form

=head1 SEE ALSO

Github Pages

=over

=item *

L<Mojolicious::Plugin::Jam|http://qtfk.github.io/Mojolicious-Plugin-Jam>

=item *

L<Mojolicious::Plugin::Jam::Form|http://qtfk.github.io/Mojolicious-Plugin-Jam/Form>

=item *

L<Mojolicious::Plugin::Jam::Form::Field|http://qtfk.github.io/Mojolicious-Plugin-Jam/Form/Field>

=back

CPAN(?)

=over

=item *

L<Mojolicious::Plugin::Jam>

=item *

L<Mojolicious::Plugin::Jam::Form>

=item *

L<Mojolicious::Plugin::Jam::Form::Button>

=item *

L<Mojolicious::Plugin::Jam::Form::Field>

=item *

L<Mojolicious::Plugin::Jam::Form::Style>

=back

Mojolicious

=over

=item *

L<Mojolicious>

=item *

L<Mojolicious::Guides>

=item *

L<http://mojolicio.us>

=back

=head1 SOURCE REPOSITORY

L<http://github.com/qtfk/Mojolicious-Plugin-Jam>

=head1 AUTHOR

qtfk <mojolicious-plugin-jam@qtfk.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by qtfk

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

package Mojolicious::Plugin::Jam;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '20130719';

use Digest::SHA 'sha256_hex';
use File::Basename 'dirname';
use File::Path 'make_path';
use File::Spec::Functions qw/catdir catfile/;

use Mojolicious::Plugin::Jam::Form;

# Versions
my %v = (
  jquery => '1.10.2',
  jquery_ui => '1.10.3',
  jquery_ui_jquery => '1.9.1',
  jquery_plugin => {
    validation => '1.11.1',
  },
  jquery_tools => '1.2.7',
);

# Paths to plugin files relative to the plugin's directory under public/js
my %plugin = (
  validation => "dist/jquery.validate.min.js",
);

# CDN's
my %cdn = (
  jquery => {
    google => "ajax.googleapis.com/ajax/libs/jquery/$v{jquery}/" .
              "jquery.min.js",
    mediatemple => "code.jquery.com/jquery-$v{jquery}.min.js",
    microsoft => "ajax.aspnetcdn.com/ajax/jQuery/jquery-$v{jquery}.min.js",
    cdnjs => "cdnjs.cloudflare.com/ajax/libs/jquery/$v{jquery}/" .
             "jquery.min.js",
  },
  jquery_ui_theme => {
    default => "code.jquery.com/ui/$v{jquery_ui}/themes",
  },
  jquery_ui_jquery => {
    default => "code.jquery.com/jquery-$v{jquery_ui_jquery}.min.js",
  },
  jquery_ui => {
    default => "code.jquery.com/ui/$v{jquery_ui}/jquery-ui.min.js",
  },
  jquery_tools => {
    default => "cdn.jquerytools.org/$v{jquery_tools}",
  },
);
my %cdn_alias = (
  jquery => {
    jquery => 'mediatemple',
    cloudflare => 'cdnjs',
    default => 'mediatemple',
  },
);
for my $i (keys %cdn) {
  while (my ($k, $v) = each %{$cdn_alias{$i}}) {
    $cdn{$i}{$k} = $cdn{$i}{$v};
  }
}

# Arrays of allowed values, converted to hashes below
my %allowed = (
  libs => ['jquery', map { "jquery_$_" } qw/ui plugin tools/],
  jquery_ui => {
    themes => [qw/black-tie blitzer cupertino dark-hive dot-luv eggplant/,
               qw/excite-bike flick hot-sneaks humanity le-frog mint-choc/,
               qw/overcast pepper-grinder redmond smoothness south-street/,
               qw/start sunny swanky-purse trontastic ui-darkness/,
               qw/ui-lightness vader/],
  },
  jquery_tools => {
    combinations => [qw/tiny form all full/, ''],
  },
);
%{$allowed{lib}} = map { $_ => 1 } @{$allowed{libs}};
%{$allowed{jquery_ui}{theme}} = map { $_ => 1 }
  @{$allowed{jquery_ui}{themes}};
%{$allowed{jquery_tools}{combination}} = map { $_ => 1 }
  @{$allowed{jquery_tools}{combinations}};

# Subrefs for libraries to load
my %lib = (
  jquery => sub {
    my $self = shift;
    my %o = @_;
    my $v = $v{jquery};
    my $src = "/js/jquery-$v.min.js";
    my $cdn = $o{cdn};
    if (defined $cdn) {
      $src = 'http://' . $cdn{jquery}{$cdn} || $cdn{jquery}{default};
    }
    my $jquery = $self->javascript($src);
    return $jquery;
  },
  jquery_ui => sub {
    my $self = shift;
    my %o = @_;
    my $v = $v{jquery_ui};

    # Theme
    my $theme = $o{theme} || 'smoothness';
    $theme = 'smoothness' unless $allowed{jquery_ui}{theme}{$theme};
    my $href = "/css/jquery-ui-themes-$v/themes/$theme/jquery-ui.min.css";
    my $cdn = $o{cdn};
    if (defined $cdn) {
      $href = "http://" . ($cdn{jquery_ui_theme}{$cdn} ||
                           $cdn{jquery_ui_theme}{default}) .
              "/$theme/jquery-ui.min.css";
    }
    my $stylesheet = $self->stylesheet($href);
    my $r = "$stylesheet\n";
    
    # jQuery
    my $jquery_src = "/js/jquery-ui-$v/jquery-$v{jquery_ui_jquery}.js";
    if (defined $cdn) {
      $jquery_src = 'http://' . $cdn{jquery_ui_jquery}{$cdn} ||
                                $cdn{jquery_ui_jquery}{default};
    }
    my $jquery_script = $self->javascript($jquery_src);
    my $current = $o{current};
    if (defined $current && $current) {
      $jquery_script = $self->jam(library => jQuery => \%o);
    }
    $r .= "    $jquery_script\n";

    # jQuery UI
    my $jquery_ui_src = "/js/jquery-ui-$v/ui/minified/jquery-ui.min.js";
    if (defined $cdn) {
      $jquery_ui_src = 'http://' . $cdn{jquery_ui}{$cdn} ||
                                  $cdn{jquery_ui}{default};
    }
    my $jquery_ui_script = $self->javascript($jquery_ui_src);
    $r .= "    $jquery_ui_script";

    return $r;
  },
  jquery_plugin => sub {
    my $self = shift;
    my %o = @_;
    my @r;
    for (sort keys %o) {
      next unless $o{$_};
      my $v = $v{jquery_plugin}{$_};
      if (defined $v) {
        my $src = "/js/jquery-$_-$v/$plugin{$_}";
        push @r, $self->javascript($src);
      } else {
        die "Invalid plugin: \"$_\"\n";
      }
    }
    return join "\n    ", @r;
  },
  jquery_tools => sub {
    my $self = shift;
    my %o = @_;
    my $c = defined $o{combination} ? $o{combination} : 'full';
    $c = 'full' unless $allowed{jquery_tools}{combination}{$c};
    my $cdn = $o{cdn};
    my $v = $v{jquery_tools};
    my $f = 'jquery.tools.min.js';
    $f = "$c/$f" if $c ne '';
    my $src = "/js/jquery-tools-$v/$f";
    if (defined $cdn) {
      $src = 'http://' . ($cdn{jquery_tools}{$cdn} ||
                          $cdn{jquery_tools}{default}) . "/$f";
    }
    return $self->javascript($src);
  },
);
$lib{'jQuery'}        = $lib{jquery};
$lib{'jQuery UI'}     = $lib{jquery_ui};
$lib{'jQuery plugin'} = $lib{jquery_plugin};
$lib{'jQuery Tools'}  = $lib{jquery_tools};

my %config = (
  security => {
    secret_length => 20,
    session_hours => 1,
    cookie_name   => 'Jam security',
    http_port     => 3000,
    https_port    => 3001,
    config_dir    => catdir($ENV{HOME}, '.mojolicious'),
    ssl_key       => 'server.key',
    ssl_crt       => 'server.crt',
    ssl_days      => 365,
    ssl_subj      => '/C=US/ST=NY/CN=*',
    logging_nav   => 1,
    server        => 'Jam security',
  },
);

# Register method
sub register {
  my ($self, $app) = @_;

  # Helper function
  $app->helper(jam => sub {
    my $self = shift;
    my $cmd = shift;

    # Library
    if ($cmd eq 'library') {
      my @r;
      for (my $i = 0; $i < @_; $i++) {
        my $lib = $_[$i];
        my %o;
        %o = %{$_[++$i]} if ref $_[$i + 1] eq 'HASH';
        die "Unrecognized library \"$lib\"" unless defined $lib{$lib};
        push @r, $lib{$lib}->($self, %o);
      }
      return join "\n    ", @r;

    # Form
    } elsif ($cmd eq 'form') {
      my $opt = shift;
      my $form;

      my $builtin = $opt->{builtin};
      if (defined $builtin) {
        if ($builtin eq 'login') {
          $opt->{id} = 'login' unless defined $opt->{id};
          $form = Mojolicious::Plugin::Jam::Form->new(%$opt);
          $form->username->required;
          $form->password->required;
          $form->submit(value => 'Go');
          $form->post;
          return $form;
        }
      }

      $form = Mojolicious::Plugin::Jam::Form->new(%$opt);

      return $form;

    # Security
    } elsif ($cmd eq 'security') {
      my $opt = shift;
      my $c = $config{security};

      # Override default configuration values
      @{$c}{keys %$opt} = values %$opt;

      # Generate certificate
      make_path $c->{config_dir} unless -d $c->{config_dir};
      my $key = catfile(@{$c}{qw/config_dir ssl_key/});
      my $crt = catfile(@{$c}{qw/config_dir ssl_crt/});
      sub cert_expired {
        my $crt = shift;
        my ($expires) = `openssl x509 -noout -in $crt -dates`
                          =~ /notAfter=(.*)\n/s;
        if ($^O eq 'darwin') {
          chomp($expires = `date -j -f '%b %e %T %Y %Z' '$expires' +%s`);
        } else {
          chomp($expires = `date -d '$expires' +%s`);
        }
        my $now = time;
        return $now >= $expires;
      }
      if (! -e $key || ! -e $crt || cert_expired $crt) {
        system sprintf "openssl req -x509 -nodes -days %d -subj '%s' " .
                       "-newkey rsa:2048 -keyout '$key' -out '$crt'",
                       @{$c}{map { "ssl_$_" } qw/days subj/};
        chmod 0600, $key, $crt;
      }
      
      # Hypnotoad configuration
      $app->config(
        hypnotoad => {
          listen => [
            "http://*:$c->{http_port}",
            "https://*:$c->{https_port}?key=$key&cert=$crt",
          ],
        },
      );
    
      # Change default passphrase
      chomp(my $secret = `openssl rand $c->{secret_length}`);
      $app->secret($secret);
      
      # Session length
      $app->sessions->default_expiration($c->{session_hours} * 3600);
      $app->defaults({ refresh => $c->{session_hours} * 3600 + 60 });
    
      # Set the cookie name
      $app->sessions->cookie_name($c->{cookie_name});
    
      # Send cookie over HTTPS only
      $app->sessions->secure(1);
    
      # Salted password hashing
      $app->helper(hash => sub {
        my $self = shift;
        chomp(my $salt = `openssl rand -hex 32`);
        my $in = $salt . join '', @_;
        my $hash = $salt . sha256_hex $in;
        return $hash;
      });
      $app->helper(validate_hash => sub {
        my $self = shift;
        my $hash = shift;
        my $salt = substr $hash, 0, 64;
        my $in = $salt . join '', @_;
        my $test = $salt . sha256_hex $in;
        return $test eq $hash;
      });
      
      # Logging
      $app->helper(log => sub {
        my $self = shift;
        my $chan = shift;
        if ($c->{"logging_$chan"}) {
          my $username = $self->session('username') || 'nobody';
          my $ip = $self->tx->remote_address;
          my $port = $self->tx->remote_port;
          my $method = $self->tx->req->method;
          my $uri = $self->tx->req->url->to_abs;
          my $msg = join ' ', @_;
          $msg ||= "\b";
          $msg = "[$chan] $msg [$username\@$ip:$port => $method $uri]";
          $self->app->log->info($msg);
        }
        return $self;
      });
      
      # For each request...
      $app->hook(before_dispatch => sub {
        my $self = shift;
        
        # Log navigation
        $self->log('nav');
    
        # Custom server header
        $self->res->headers->server($c->{server});
    
        # Redirect http to https
        my $scheme = $self->tx->req->url->base->scheme;
        my $host = $self->tx->req->url->base->host;
        my $path = $self->tx->req->url->base->path->to_string ||
                   $self->tx->req->url->path->to_string;
        if ($scheme eq 'http' && $host ne 'localhost') {
          my $port = $c->{https_port} != 443 ? ":$c->{https_port}" : '';
          my $target = join '', 'https://', $host, $port, $path;
          $self->log('nav', "Redirecting to \"$target\"");
          $self->redirect_to($target);
          return;
        }
    
        # Expire content and don't cache
        $self->res->headers->expires('0');
        $self->res->headers->cache_control('max-age=0, no-store, no-cache, must-revalidate');
    
      });
    
      # Register the templates directory for the default layout
      my $base = catdir(dirname(__FILE__), 'Jam');
      push @{$app->renderer->paths}, catdir($base, 'templates');

    } else {
      die "Unrecognized command \"$cmd\"";
    }
  });

  # Register the public directory
  my $base = catdir(dirname(__FILE__), 'Jam');
  push @{$app->static->paths}, catdir($base, 'public');

  return 1;
}

1;

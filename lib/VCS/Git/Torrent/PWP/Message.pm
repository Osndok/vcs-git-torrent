
=head1 NAME

VCS::Git::Torrent::PWP::Message - role for PWP messages

=head1 SYNOPSIS

 # general interface
 use VCS::Git::Torrent::PWP::Message qw(:constants);

 # subclass interface
 package VCS::Git::Torrent::PWP::Message::Foo;

 extends 'VCS::Git::Torrent::PWP::Message';

 # return the payload from the object, or set object up
 sub payload {
     ...
 }

 # return new() arguments from a pwp_message list
 sub args {

 }

 1;

=head1 DESCRIPTION

This is a base class for PWP messages.

Messages must define their data members themselves, but critically,
return the body of the message as sent on the wire with "pack", and
accept a message with "unpack", setting up their relevant members.

=cut

package VCS::Git::Torrent::PWP::Message;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Class::Autouse;
use Carp;

my %constants;
our @TYPE_CLASS;
our %CLASS_TYPE;
BEGIN {
	my @message_types =
		qw(choke unchoke interested uninterested peers
		   references reels blocks scan request play stop);
	require constant;
	for ( my $i = 0; $i <= $#message_types; $i++ ) {
		my $t = $message_types[$i];
		$constants{"GTP_PWP_".uc($t)} = $i;
		my $class = __PACKAGE__."::".ucfirst($t);
		push @TYPE_CLASS, $class;
		$CLASS_TYPE{$class} = $i;
		eval { Class::Autouse->import($class); };
	}

	constant->import(\%constants);
}

use Sub::Exporter -setup =>
	{ exports =>
	  [ keys %constants,
	  ],
	  groups =>
	  { constants => [ keys %constants ],
	  },
	};

subtype "VCS::Git::Torrent::PWP::Message::Type"
	=> as "Int"
	=> where { $_ >= 0 and $_ <= $#TYPE_CLASS };

has 'type' =>
	(isa => "VCS::Git::Torrent::PWP::Message::Type");

has 'length' =>
	is => 'ro',
	isa => "Int",
	lazy => 1,
	required => 1,
	default => sub {
		no warnings 'uninitialized';
		my $self = shift;
		CORE::length($self->payload)+4;
	};

my $i = 0;
sub pack {
	my $self = shift;

	my @rv = grep { defined }
		(CORE::pack("NN", $self->length, $self->type),
		 $self->payload);

	return wantarray ? @rv : join "", @rv;
}

requires 'payload';
requires 'args';

sub create_io {
	my $base_class = shift;
	my $io = shift;

	my $header;
	my $bytes_read = $io->read($header, 8);
	return undef if !$bytes_read;
	die "Could not read PWP header" if $bytes_read < 8;

	my ($_length, $_type) = CORE::unpack("NN", $header);
	$_length -= 4;

	my $class = $base_class->class_for($_type);

	my $payload;
	$bytes_read = $io->read($payload, $_length);
	if ( $bytes_read != $_length ) {
		die "Expected ".$_length." bytes, got ".$bytes_read;
	}

	$class->new( length => $_length,
		     payload => $payload );
}

my %LOADED;
no warnings 'redefine';

sub class_for {
	shift;
	my $type = shift;
	$TYPE_CLASS[$type]
		or croak "bad PWP message type $type";
}

sub create {
	my $class = (shift)->class_for(shift);
	Class::Autouse->autouse($class)
			unless $LOADED{$class}++;

	$class->new( $class->args(@_) );
}

sub type {
	my $self = shift;
	$CLASS_TYPE{(ref $self)||$self}
}

=head1 LICENSE

  Copyright (C) 2007  Sam Vilain

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program, as the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

=cut

1;

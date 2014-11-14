#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use Devel::Dwarn;

use lib "t/lib";
use TestDS;
use TestDS_HAL;
use WebAPI::DBIC::WebApp;

use Test::DBIx::Class;
fixtures_ok qw/basic/;

subtest "===== Update a resource and related resources via PUT =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
    })->to_psgi_app;

    my $orig_item;
    my $orig_location;

    # POST to the set to create a Track to edit, and also create a CD
    test_psgi $app, sub {
        my $res = shift->(dsreq_hal( POST => "/track?prefetch=self", [], {
            title => "Just One More",
            position => 42,
            _embedded => {
                disc => {
                    artist => 1,
                    title => 'The New New',
                    year => '2014',
                    genreid => 1,
                }
            }
        }));
        ($orig_location, $orig_item) = dsresp_created_ok($res);
    };

    # PUT to the item to update the item and the related CD
    test_psgi $app, sub {
        my $res = shift->(dsreq_hal( PUT => "/track/$orig_item->{trackid}?prefetch=self,disc", [], {
            title => "Just One More (remix)",
            _embedded => {
                disc => {
                    title => "The New New (mostly)"
                }
            }
        }));
        my $data = dsresp_ok($res);

        is ref $data, 'HASH', 'return data';
        ok $data->{trackid}, 'has trackid assigned';
        is $data->{title}, "Just One More (remix)";
        is $data->{position}, $orig_item->{position}, 'has same position assigned';

        ok $data->{_embedded}, 'has _embedded';
        ok my $disc = $data->{_embedded}{disc}, 'has embedded disc';
        is $disc->{title}, "The New New (mostly)";
        is $disc->{year}, 2014;
    };

    note "recheck data as a separate request";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/track/$orig_item->{trackid}?prefetch=self,disc")));
        ok $data->{trackid}, 'has trackid assigned';
        is $data->{title}, "Just One More (remix)";
        is $data->{position}, $orig_item->{position}, 'has same position assigned';

        ok $data->{_embedded}, 'has _embedded';
        ok my $disc = $data->{_embedded}{disc}, 'has embedded disc';
        is $disc->{title}, "The New New (mostly)";
        is $disc->{year}, 2014;
    };

    test_psgi $app, sub {
        dsresp_ok(shift->(dsreq_hal( DELETE => "/track/$orig_item->{trackid}")), 204);
    };

};

done_testing();

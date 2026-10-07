#!/usr/bin/perl
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Copy qw(copy);
use File::Path qw(make_path);

my $root = 'regress/results/csv';
my $target = "$root/age_load";
my @invalid = map { "$target/conversion_$_.txt" } qw(vertices edges);

if (@ARGV && $ARGV[0] eq '--touch')
{
    for my $file (@invalid)
    {
        open my $fh, '>', $file or die "Cannot create $file: $!";
        close $fh or die "Cannot close $file: $!";
    }
    exit 0;
}

die "Usage: $0 [--touch]\n" if @ARGV;
make_path($target);
for my $file (@invalid)
{
    unlink $file or die "Cannot remove fixture $file: $!" if -e $file;
}
for my $file (glob 'regress/age_load/data/*.csv')
{
    copy($file, $target) or die "Cannot copy $file: $!";
}

my $path = abs_path($root);
if ($^O eq 'msys' || $^O eq 'cygwin')
{
    open my $pipe, '-|', 'cygpath', '-m', $path or die "Cannot run cygpath: $!";
    $path = <$pipe>;
    close $pipe or die "cygpath failed";
    chomp $path;
}
$path =~ s{\\}{/}g;
$path =~ s/'/''/g;
open my $setup, '>', 'regress/results/age_load_setup.sql' or die $!;
print {$setup} "SET age.csv_directory TO '$path';\n";
close $setup or die $!;

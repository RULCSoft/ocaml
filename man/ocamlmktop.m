\" $Id$
.TH OCAMLMKTOP 1

.SH NAME
ocamlmktop \- Building custom toplevel systems

.SH SYNOPSIS
.B ocamlmktop
[
.B \-v
]
[
.BI \-cclib \ libname
]
[
.BI \-ccopt \ option
]
[
.B \-custom
[
.BI \-o \ exec-file
]
[
.BI \-I \ lib-dir
]
.I filename ...

.SH DESCRIPTION

The
.BR ocamlmktop (1)
command builds Objective Caml toplevels that
contain user code preloaded at start-up.
The
.BR ocamlmktop (1)
command takes as argument a set of
.IR x .cmo
and
.IR x .cma
files, and links them with the object files that implement the Objective
Caml toplevel.  If the
.B \-custom
flag is given, C object files and libraries (.o and .a files) can also
be given on the command line and are linked in the resulting toplevel.

.SH OPTIONS

The following command-line options are recognized by
.BR ocamlmktop (1).
.TP
.B \-v
Print the version number of the compiler.
.TP
.BI \-cclib\ \-l libname
Pass the
.BI \-l libname
option to the C linker when linking in
``custom runtime'' mode (see the corresponding option for
.BR ocamlc (1).
.TP
.B \-ccopt
Pass the given option to the C compiler and linker, when linking in
``custom runtime'' mode. See the corresponding option for
.BR ocamlc (1).
.TP
.B \-custom
Link in ``custom runtime'' mode. See the corresponding option for
.BR ocamlc (1).
.TP
.BI \-I \ directory
Add the given directory to the list of directories searched for
compiled interface files (.cmo and .cma).
.TP
.BI \-o \ exec\-file
Specify the name of the toplevel file produced by the linker.
The default is is
.BR a.out .

.SH SEE ALSO
.BR ocamlc (1).

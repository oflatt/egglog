use clap::Parser;
use egg_smol::EGraph;
use egg_smol::IncludeTempFunctions;
use std::io::{self, Read};
use std::path::PathBuf;

#[derive(Debug, Parser)]
struct Args {
    #[clap(short = 'F', long)]
    fact_directory: Option<PathBuf>,
    #[clap(long)]
    naive: bool,
    #[clap(long)]
    save_dot: bool,
    #[clap(long)]
    save_svg: bool,
    #[clap(long)]
    #[clap(value_enum, default_value_t=IncludeTempFunctions::IfProofsEnabled)]
    viz_include_temp: IncludeTempFunctions,
    inputs: Vec<PathBuf>,
}


fn main() {
    env_logger::Builder::new()
        .filter_level(log::LevelFilter::Info)
        .format_timestamp(None)
        .format_target(false)
        .parse_default_env()
        .init();

    let args = Args::parse();

    let mk_egraph = || {
        let mut egraph = EGraph::default();
        egraph.fact_directory = args.fact_directory.clone();
        egraph.seminaive = !args.naive;
        egraph
    };

    if args.inputs.is_empty() {
        let stdin = io::stdin();
        log::info!("Welcome to Egglog!");
        let mut egraph = mk_egraph();
        let mut program = String::new();
        stdin
            .lock()
            .read_to_string(&mut program)
            .unwrap_or_else(|_| panic!("Failed to read program from stdin"));
        match egraph.parse_and_run_program(&program) {
            Ok(_msgs) => {}
            Err(err) => {
                log::error!("{}", err);
            }
        }

        std::process::exit(1)
    }

    for (idx, input) in args.inputs.iter().enumerate() {
        log::info!("Running {}", input.display());
        let s = std::fs::read_to_string(input).unwrap_or_else(|_| {
            let arg = input.to_string_lossy();
            panic!("Failed to read file {arg}")
        });
        let mut egraph = mk_egraph();
        match egraph.parse_and_run_program(&s) {
            Ok(_msgs) => {}
            Err(err) => {
                log::error!("{}", err);
                std::process::exit(1)
            }
        }

        // Save the graph as a DOT file if the `save_dot` flag is set
        if args.save_dot {
            let dot_path = input.with_extension("dot");
            match egraph.save_graph_as_dot(&dot_path, args.viz_include_temp) {
                Ok(()) => log::info!("Saved graph as DOT file: {}", dot_path.display()),
                Err(err) => log::error!("Failed to save graph as DOT file: {}", err),
            }
        }

        // Save the graph as an SVG file if the `save_svg` flag is set
        if args.save_svg {
            let svg_path = input.with_extension("svg");
            match egraph.save_graph_as_svg(&svg_path, args.viz_include_temp) {
                Ok(()) => log::info!("Saved graph as SVG file: {}", svg_path.display()),
                Err(err) => log::error!("Failed to save graph as SVG file: {}", err),
            }
        }

        // no need to drop the egraph if we are going to exit
        if idx == args.inputs.len() - 1 {
            std::mem::forget(egraph)
        }
    }
}

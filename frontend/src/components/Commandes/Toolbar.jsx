import { Filter } from "lucide-react";
import { CSVLink } from "react-csv";

export const Toolbar = (props) => {
  return (
    <div className="toolbar">
      <div className="toolbar-left">
        <button className="icon-pill" type="button" aria-label="Filtres">
          <Filter size={18} />
        </button>

        <select
          className="tool-select"
          value={props.statusFilter}
          onChange={(e) => props.setStatusFilter(e.target.value)}
        >
          <option value="">Tous les statuts</option>
          {props.status.map((item,i) => {
            return <option value={item} key={i}>{item}</option>;
          })}
        </select>

        <select
          className="tool-select"
          value={props.typeFilter}
          onChange={(e) => props.setTypeFilter(e.target.value)}
        >
          <option value="">Tous les types</option>
          {props.types.map((item,i) => {
            return <option value={item} key={i}>{item}</option>;
          })}
        </select>
      </div>

      <div className="toolbar-right">
        <button className="btn-ghost" type="button">
          <CSVLink
            data={props.filteredexpot}
            filename={props.filename + ".csv"}
            style={{ color: "red", textDecoration: "none" }}
          >
            Exporter CSV
          </CSVLink>
        </button>
      </div>
    </div>
  );
};
